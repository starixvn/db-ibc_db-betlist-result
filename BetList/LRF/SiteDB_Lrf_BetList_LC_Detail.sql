/*<info serverAlias="DBSID-bodb02" executers="bodbLicenseeNet" viewers="" isFunction="0" isNested="0"></info>*/

ALTER PROCEDURE [dbo].[SiteDB_Lrf_BetList_LC_Detail]
	@AgentList		VARCHAR(MAX),
	@CustId			INT,
	@RefNo			BIGINT,
	@TransType		TINYINT			= 0,
	@MoveBetsDay	SMALLDATETIME,
	@BalanceUpDay	SMALLDATETIME,
	@BaseCurrency	VARCHAR(12)
AS

/*
	Created: 20220727@Kos
	Task: LAP - Bet List - Get ticket detail of LC Casino products - SiteDB
	DB: DBSID.bodb02
	Revisions:
		- 20220727@Kos: Scale out DBTRANS [Redmine: #175297]
		- 20220922@Kos: Support crypto currency [Redmine: 177481]
		- 20221220@Kos: Remove inactive products GDG [Redmine: 181424]
		- 20230602@Kos: Support YeeBet [Redmine: 187947]
		- 20231110@Kos: Support WE Live Casino [Redmine: 196573]

	Parameters:
		- @TransType
			+ 0 : All (DRAW/WON/LOSE/Reject/Void/Refund/Running/Waiting)
			+ 1 : DRAW/WON/LOSE/Void/Reject/Refund
			+ 2 : Reject/Void
			+ 3 : Running/Waiting
*/

BEGIN
	SET NOCOUNT ON

	DECLARE @TempAg TABLE (CustId INT, Currency INT)

	-- Get AgentList
	DECLARE @DocHandler INT

	BEGIN TRY
		EXEC sp_xml_preparedocument @DocHandler OUTPUT, @AgentList
	
		INSERT INTO @TempAg (CustId, Currency)
		SELECT AgentId, Currency
		FROM OPENXML(@DocHandler, '/ROOT/Agent', 1) WITH (AgentId INT, Currency INT) AS Data

		EXEC sp_xml_removedocument @DocHandler
	END TRY
	BEGIN CATCH
		SELECT ErrCode = 100,
			ErrMsg = N'Parameter invalid.'

		RETURN
	END CATCH

	-- Get SportBetTypeMatrix
	DECLARE @SportBettype TABLE(ProductID TINYINT, Bettype SMALLINT, EventType TINYINT)

	DECLARE @IsTest BIT = 0

	SELECT @IsTest = dbo.f_CheckSPVersion(@@PROCID)

	-- Support AG Casino Single Wallet, AllBet
	INSERT INTO @SportBettype
	SELECT ProductID, BetType, EventType
	FROM dbo.f_SportBettypeMatrix_Sel (0, 0, 0, 2, '', '', @IsTest)
	WHERE RefTable = 2 AND ProductID NOT IN (46, 52, 59, 65)

	DECLARE @tmpStatus TABLE (StatusId TINYINT)

	IF @TransType = 0
	BEGIN
		INSERT INTO @tmpStatus (StatusId)
		SELECT 111 UNION ALL
		SELECT 112 UNION ALL
		SELECT 113 UNION ALL
		SELECT 101 UNION ALL
		SELECT 102 UNION ALL
		SELECT 103 UNION ALL
		SELECT 0 UNION ALL
		SELECT 1
	END
	ELSE IF @TransType = 1
	BEGIN
		INSERT INTO @tmpStatus (StatusId)
		SELECT 111 UNION ALL
		SELECT 112 UNION ALL
		SELECT 113 UNION ALL
		SELECT 101 UNION ALL
		SELECT 102 UNION ALL
		SELECT 103
	END
	ELSE IF @TransType = 2
	BEGIN
		INSERT INTO @tmpStatus (StatusId)
		SELECT 101 UNION ALL
		SELECT 102
	END 
	ELSE IF @TransType = 3
	BEGIN
		INSERT INTO @tmpStatus (StatusId)
		SELECT 0 UNION ALL
		SELECT 1
	END

	DECLARE @tmpBettransLC TABLE (
		TransId			BIGINT,
		SportType		SMALLINT,
		BetType			SMALLINT,
		TransDate		DATETIME,
		WinLostDate		SMALLDATETIME,
		Status			VARCHAR(10),
		StatusId		TINYINT,
		Odds			MONEY,
		Stake			MONEY,
		Actual_Stake	MONEY,
		WinLost			MONEY,
		Comm			MONEY,
		PlayerComm		MONEY,
		Ip				VARCHAR(45),
		TransDesc		NVARCHAR(1000),
		BetCheck		NVARCHAR(2000),
		MatchCode		VARCHAR(50),
		BetTeam			NVARCHAR(100),
		SiteId			VARCHAR(7),
		EventDate		DATETIME
	)

	IF EXISTS ( SELECT 1 FROM dbo.bettrans WITH (NOLOCK) WHERE transid = @RefNo AND winlostdate > @MoveBetsDay )
	BEGIN
		INSERT INTO @tmpBettransLC
		SELECT
			CASE
				WHEN sbt.ProductID = 39 THEN ISNULL(bg.transid, 0)
				ELSE blc.transid
			END AS TransId,
			blc.productID AS SportType,
			blc.gameID AS BetType,
			CASE
				WHEN sbt.ProductID = 39 THEN ISNULL(bg.transdate, '')
				ELSE blc.transdate
			END AS TransDate,
			blc.winlostdate,
			CASE
				WHEN sbt.ProductID = 39 THEN ISNULL(bg.status, '')
				ELSE blc.status
			END AS Status,
			CASE
				WHEN sbt.ProductID = 39 THEN ISNULL(bg.statusID, 0)
				ELSE blc.statusID
			END AS StatusId,
			CASE
				WHEN sbt.ProductID = 39 THEN ISNULL(bg.odds, 0)
				ELSE blc.odds
			END AS Odds,
			CASE
				WHEN sbt.ProductID = 39 THEN ISNULL(bg.stake, 0)
				ELSE blc.stake
			END AS Stake,
			CASE
				WHEN sbt.ProductID = 39 THEN ISNULL(bg.actual_stake, 0)
				ELSE blc.actual_stake
			END AS Actual_Stake,
			CASE
				WHEN sbt.ProductID = 39 THEN ISNULL(bg.winlost - bg.actual_stake, 0)
				ELSE blc.winlost - blc.actual_stake
			END AS WinLost,
			CASE
				WHEN sbt.ProductID = 39 THEN ISNULL(bg.comm, 0)
				ELSE blc.comm
			END AS Comm,
			CASE
				WHEN sbt.ProductID = 39 THEN ISNULL(bg.playercomm, 0)
				ELSE blc.playercomm
			END AS PlayerComm,
			blc.ip,
			blc.transdesc,
			CASE
				WHEN sbt.ProductID = 39 THEN ISNULL(bg.TransDesc, '')
				ELSE blc.TranId3rd
			END AS BetCheck,
			blc.GameId3rd AS MatchCode,
			CASE
				WHEN sbt.productID = 39 THEN ISNULL(bg.BetID3rd, '')
				ELSE ''
			END AS BetTeam,
			blc.SiteId,
			CASE
				WHEN sbt.ProductID IN (70) THEN blc.TransDate3rd
				ELSE ''
			END AS EventDate
		FROM dbo.bettransLC AS blc WITH (NOLOCK)
			INNER JOIN @SportBettype AS sbt ON blc.gameID = sbt.Bettype
			LEFT JOIN dbo.bettransg AS bg WITH (NOLOCK)
				ON bg.refno = blc.transid
				AND bg.custid = blc.custid
				AND sbt.ProductID = 39
		WHERE blc.custid = @CustId 
			AND blc.RefNo = @RefNo
			AND blc.statusID IN (SELECT StatusId FROM @tmpStatus)
	END

	-- Get exchange rate
	DECLARE @ExFromDate SMALLDATETIME,
		@ExToDate SMALLDATETIME

	SELECT
		@ExFromDate = MIN(WinLostDate),
		@ExToDate = MAX(WinLostDate)
	FROM @tmpBettransLC

	-- Get exchange rate
	DECLARE @ExchangeRate TABLE (
		FirstExchangeDateByMonth	SMALLDATETIME,
		LastExchangeDateByMonth		SMALLDATETIME,
		Rate						FLOAT
	)

	-- Get currency (for security)
	DECLARE @Currency INT

	SELECT @Currency = currency
	FROM CustDB.dbo.custinfo WITH (NOLOCK)
	WHERE custid = @CustId
		AND currency IN (SELECT DISTINCT Currency FROM @TempAg)

	IF @BaseCurrency <> ''
	BEGIN
		INSERT INTO @ExchangeRate
		SELECT
			e.FromDate,
			e.ToDate,
			e.Rate
		FROM dbo.SiteDB_Lrf_f_GetExchangeRate(@ExFromDate, @ExToDate, @BaseCurrency, '') AS e
		WHERE e.ExchangeId = @Currency
			AND EXISTS (SELECT 1 FROM @tmpBettransLC WHERE WinLostDate BETWEEN e.FromDate AND e.ToDate)
	END

	SELECT
		b.TransId,
		b.SportType,
		b.BetType,
		b.TransDate,
		b.WinLostDate,
		b.Status,
		b.StatusId,
		b.Odds,
		b.Stake * ISNULL(e.Rate, 1) AS Stake,
		b.Actual_Stake,
		b.WinLost * ISNULL(e.Rate, 1) AS WinLost,
		b.Comm * ISNULL(e.Rate, 1) AS Comm,
		b.PlayerComm * ISNULL(e.Rate, 1) AS PlayerComm,
		b.Ip,
		b.TransDesc,
		b.BetCheck,
		b.MatchCode,
		b.BetTeam,
		@Currency AS Currency,
		@Currency AS LeagueId,
		b.SiteId,
		b.EventDate
	FROM @tmpBettransLC AS b
		LEFT JOIN @ExchangeRate AS e ON b.WinLostDate BETWEEN e.FirstExchangeDateByMonth AND e.LastExchangeDateByMonth
	ORDER BY b.TransId ASC
END
GO
