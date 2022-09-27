/*<info serverAlias="DBACC-bodb02" executers="bodbLicenseeNet" viewers="" isFunction="0" isNested="0"></info>*/

ALTER PROCEDURE [dbo].[Lrf_BetList_LC_Detail]
	@AgentList			VARCHAR(MAX),
	@CustId				INT,
	@RefNo				BIGINT,
	@TransType			TINYINT		= 0,
	@ExcludeBettrans	BIT			= 0,
	@MoveBetsDay		SMALLDATETIME,
	@BalanceUpDay		SMALLDATETIME,
	@BaseCurrency		VARCHAR(12)
AS

/*
	Created: Kos@20150923
	Task : Get ticket detail from table betransLC (AG Casino)
	DB: DBACC.bodb02

	Revisions:
		- 20160530@Kos: Add ORDER BY statement to correct ticket order [Redmine: #58448]
		- 20160727@Kos: Include Void/Rejected detail tickets view drilldown WON/LOSE/DRAW summary tickets
					- Change to use inline function for SportBetTypeMatrix
		- 20170307@Kos: Support sub licensees [#Redmine: 71679]
		- 20190524@Kos: Add new input param @BaseCurrency [#Redmine: 112531]
		- 20200427@Kos: Support Sexy Gaming [Redmine: #130859]
					- Return addtional column BetTeam NVARCHAR(50)
		- 20200616@Kos: Support SA Gaming [Redmine: #128493]
		- 20210112@Kos: Support GDG [Redmine: #147267]
		- 20210301@Kos: Add BDT and INR as base currencies [Redmine: 150375]
		- 20210506@Kos: Support WM Live Casino [Redmine: #140944]
		- 20210519@Kos: Support Big Gaming [Redmine: #146773]
		- 20210929@Kos: Extend length to support IPv6 [Redmine: 162342]
		- 20211029@Kos: Decompress IP in bk range [Redmine: 162342]
					- Add new params @MoveBetsDay SMALLDATETIME and @BalanceUpDay SMALLDATETIME
		- 20220113@Kos: Support new 3rd result API [Redmine: #166047]
		- 20220330@Kos: Support FGG [Redmine: #167897]
		- 20220727@Kos: Scale out DBTRANS [Redmine: #175297]
					- Add new input param @ExcludeBettrans BIT
					- Move from DBEXT to DBACC
		- 20230922@Kos: Support crypto currency [Redmine: 177481]

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
	WHERE ProductID IN (11, 21, 39, 45, 51, 57, 59, 70)

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

	IF @ExcludeBettrans = 0
		AND EXISTS ( SELECT 1 FROM dbo.bettrans WITH (NOLOCK) WHERE transid = @RefNo AND winlostdate > @MoveBetsDay )
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
				WHEN sbt.productID IN (21, 45, 51, 57, 59, 70) THEN blc.TranId3rd
				WHEN sbt.ProductID = 39 THEN ISNULL(bg.TransDesc, '')
				ELSE ''
			END AS BetCheck,
			CASE
				WHEN sbt.productID IN (21, 39, 45, 51, 57, 59, 70) THEN blc.GameId3rd
				ELSE ''
			END AS MatchCode,
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
	ELSE IF EXISTS ( SELECT 1 FROM dbo.bettrans14 WITH (NOLOCK) WHERE transid = @RefNo AND winlostdate BETWEEN @BalanceUpDay AND @MoveBetsDay )
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
				WHEN sbt.productID IN (21, 45, 51, 57, 59, 70) THEN blc.TranId3rd
				WHEN sbt.ProductID = 39 THEN ISNULL(bg.TransDesc, '')
				ELSE ''
			END AS BetCheck,
			CASE
				WHEN sbt.productID IN (21, 39, 45, 51, 57, 59, 70) THEN blc.GameId3rd
				ELSE ''
			END AS MatchCode,
			CASE
				WHEN sbt.productID = 39 THEN ISNULL(bg.BetID3rd, '')
				ELSE ''
			END AS BetTeam,
			blc.SiteId,
			CASE
				WHEN sbt.ProductID IN (70) THEN blc.TransDate3rd
				ELSE ''
			END AS EventDate
		FROM dbo.bettransLC14 AS blc WITH (NOLOCK)
			INNER JOIN @SportBettype AS sbt ON blc.gameID = sbt.Bettype
			LEFT JOIN dbo.bettransg14 AS bg WITH (NOLOCK)
				ON bg.refno = blc.transid
				AND bg.custid = blc.custid
				AND sbt.ProductID = 39
		WHERE blc.custid = @CustId AND blc.RefNo = @RefNo
	END
	ELSE IF EXISTS ( SELECT 1 FROM bodb_Archive.dbo.bettrans_bk WITH (NOLOCK) WHERE transid = @RefNo )
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
			dp.IP,
			blc.transdesc,
			CASE
				WHEN sbt.productID IN (21, 45, 51, 57, 59, 70) THEN blc.TranId3rd
				WHEN sbt.ProductID = 39 THEN ISNULL(bg.TransDesc, '')
				ELSE ''
			END AS BetCheck,
			CASE
				WHEN sbt.productID IN (21, 39, 45, 51, 57, 59, 70) THEN blc.GameId3rd
				ELSE ''
			END AS MatchCode,
			CASE
				WHEN sbt.productID = 39 THEN ISNULL(bg.BetID3rd, '')
				ELSE ''
			END AS BetTeam,
			blc.SiteId,
			CASE
				WHEN sbt.ProductID IN (70) THEN blc.TransDate3rd
				ELSE ''
			END AS EventDate
		FROM bodb_Archive.dbo.bettransLC_bk AS blc WITH (NOLOCK)
			INNER JOIN @SportBettype AS sbt ON blc.gameID = sbt.Bettype
			LEFT JOIN bodb_Archive.dbo.bettransg AS bg WITH (NOLOCK)
				ON bg.refno = blc.transid
				AND bg.custid = blc.custid
				AND sbt.ProductID = 39
			CROSS APPLY dbo.f_IP_Decompress(blc.ip) AS dp
		WHERE blc.custid = @CustId AND blc.RefNo = @RefNo
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
	FROM dbo.custinfo WITH (NOLOCK)
	WHERE custid = @CustId
		AND currency IN (SELECT DISTINCT Currency FROM @TempAg)

	IF @BaseCurrency <> ''
	BEGIN
		INSERT INTO @ExchangeRate
		SELECT
			e.FromDate,
			e.ToDate,
			e.Rate
		FROM dbo.Lrf_f_GetExchangeRate(@ExFromDate, @ExToDate, @BaseCurrency, '') AS e
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
