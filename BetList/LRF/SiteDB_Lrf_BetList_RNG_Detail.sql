/*<info serverAlias="DBSID-bodb02" executers="wsv_lap" viewers="" isFunction="0" isNested="0"></info>*/

ALTER PROCEDURE [dbo].[SiteDB_Lrf_BetList_RNG_Detail]
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
	Task: LAP - Bet List - Get ticket detail of RNG Casino products - SiteDB
	DB: DBSID.bodb02
	Revisions:
		- 20220727@Kos: Scale out DBTRANS [Redmine: #175297]
		- 20220922@Kos: Support crypto currency [Redmine: 177481]
		- 20221220@Kos: Remove inactive products FW [Redmine: 181424]
		- 20230905@Kos: Support TxId for MaxGame [Redmine: 193273]
		- 20231019@Kos: Adjust due to new column ExtraInfo [Redmine: 195780]
					- Return new JackpotInfo column
		- 20240102@Kos: Extend data type [Redmine: 198966]
		- 20250225@Kos: Fix bug FLOAT rounding [#Redmine: 194970]

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
	DECLARE @SportBettype TABLE(ProductID TINYINT, Bettype SMALLINT, EventType TINYINT, SubProduct VARCHAR(500))

	DECLARE @IsTest BIT = 0

	SELECT @IsTest = dbo.f_CheckSPVersion(@@PROCID)

	INSERT INTO @SportBettype
	SELECT ProductID, BetType, EventType, SubProduct
	FROM dbo.f_SportBettypeMatrix_Sel (0, 0, 0, 2, '', '', @IsTest)
	WHERE RefTable = 1 AND ProductID NOT IN (17, 24, 50)

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

	DECLARE @tmpBettransRnG TABLE (
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
		LicenseeWL		MONEY,
		Comm			MONEY,
		PlayerComm		MONEY,
		Ip				VARCHAR(45),
		TransDesc		NVARCHAR(1000),
		BetCheck		VARCHAR(200),
		MatchCode		VARCHAR(1000),
		BetTeam			NVARCHAR(100),
		OddsSpread		MONEY,
		BetdaqId		BIGINT,
		ExtraInfo		VARCHAR(1000),
		JackpotInfo		VARCHAR(50),
		SiteId			VARCHAR(7),
		EventDate		DATETIME
	)

	IF EXISTS ( SELECT 1 FROM dbo.bettrans WITH (NOLOCK) WHERE transid = @RefNo AND winlostdate > @MoveBetsDay)
	BEGIN
		INSERT INTO @tmpBettransRnG
		SELECT
			brng.transid,
			brng.productID AS SportType,
			brng.gameID AS BetType,
			brng.transdate,
			brng.winlostdate,
			brng.status,
			brng.statusID,
			CASE
				WHEN sbt.ProductID IN (32, 36, 42, 66) AND brng.statusID IN (111, 112, 113) THEN ISNULL(brng.ContributionRate, 0)
				ELSE brng.odds
			END AS Odds,
			brng.stake,
			brng.actual_stake,
			CASE
				WHEN brng.statusID IN (0, 1) THEN 0
				ELSE (brng.winlost - brng.actual_stake)
			END AS WinLost,
			CASE
				WHEN brng.statusID IN (0, 1) THEN 0
				ELSE - (brng.winlost - brng.actual_stake)
			END AS LicenseeWL,
			CASE
				WHEN brng.statusID IN (0, 1) THEN 0
				ELSE brng.comm
			END AS Comm,
			brng.playercomm,
			brng.ip,
			brng.transdesc,
			brng.TranId3rd AS BetCheck,
			CASE
				WHEN sbt.productID IN (42) THEN ISNULL(brng.SiteID, '')
				ELSE brng.Additional
			END AS MatchCode,
			brng.GameId3rd AS BetTeam,
			CASE
				WHEN sbt.ProductID IN (32, 36, 42, 66) AND brng.statusID IN (111, 112, 113) THEN ISNULL(brng.BetStake, 0)
				ELSE 0
			END AS OddsSpread,
			CASE
				WHEN sbt.ProductID IN (32, 36, 42, 66) THEN ISNULL(brng.RefNo2, -1)
				ELSE -1
			END AS BetdaqId,
			brng.ExtraInfo,
			CASE
				WHEN sbt.ProductID IN (32, 36, 42, 66) THEN ISNULL(brng.JackpotInfo, '')
				ELSE ''
			END AS JackpotInfo,
			ISNULL(brng.SiteID, '') AS SiteId,
			CASE
				WHEN sbt.productID IN (60) THEN brng.Transdate3rd
				ELSE ''
			END AS EventDate
		FROM dbo.bettransRnG AS brng WITH (NOLOCK)
			INNER JOIN @SportBettype AS sbt ON brng.gameID = sbt.Bettype
		WHERE brng.custid = @CustId
			AND brng.RefNo = @RefNo
			AND brng.statusID IN (SELECT StatusId FROM @tmpStatus)
	END

	-- Get exchange rate
	DECLARE @ExFromDate SMALLDATETIME,
		@ExToDate SMALLDATETIME

	SELECT
		@ExFromDate = MIN(WinLostDate),
		@ExToDate = MAX(WinLostDate)
	FROM @tmpBettransRnG

	-- Get exchange rate
	DECLARE @ExchangeRate TABLE (
		FirstExchangeDateByMonth	SMALLDATETIME,
		LastExchangeDateByMonth		SMALLDATETIME,
		Rate						FLOAT
	)

	-- get currency (for security)
	DECLARE @Currency	INT

	SELECT @Currency = c.currency
	FROM CustDB.dbo.custinfo AS c WITH (NOLOCK)
	WHERE c.custid = @CustId
		AND c.currency IN (SELECT DISTINCT Currency FROM @TempAg)

	IF @BaseCurrency <> ''
	BEGIN
		INSERT INTO @ExchangeRate
		SELECT
			e.FromDate,
			e.ToDate,
			e.Rate
		FROM dbo.SiteDB_Lrf_f_GetExchangeRate(@ExFromDate, @ExToDate, @BaseCurrency, '') AS e
		WHERE e.ExchangeId = @Currency
			AND EXISTS (SELECT 1 FROM @tmpBettransRnG WHERE WinLostDate BETWEEN e.FromDate AND e.ToDate)
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
		CAST(b.Stake * ISNULL(e.Rate, 1) AS DECIMAL(19, 8)) AS Stake,
		b.Actual_Stake,
		CAST(b.WinLost * ISNULL(e.Rate, 1) AS DECIMAL(19, 8)) AS WinLost,
		CAST(b.LicenseeWL * ISNULL(e.Rate, 1) AS DECIMAL(19, 8)) AS LicenseeWL,
		CAST(b.Comm * ISNULL(e.Rate, 1) AS DECIMAL(19, 8)) AS Comm,
		CAST(b.PlayerComm * ISNULL(e.Rate, 1) AS DECIMAL(19, 8)) AS PlayerComm,
		b.Ip,
		b.TransDesc,
		b.BetCheck,
		b.MatchCode,
		b.BetTeam,
		b.OddsSpread,
		b.BetdaqId,
		b.ExtraInfo,
		b.JackpotInfo,
		@Currency AS Currency,
		b.SiteId,
		b.EventDate
	FROM @tmpBettransRnG AS b
		LEFT JOIN @ExchangeRate AS e ON b.WinLostDate BETWEEN e.FirstExchangeDateByMonth AND e.LastExchangeDateByMonth
	ORDER BY b.TransId ASC
END
GO
