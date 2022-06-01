/*<info serverAlias="DBEXT-bodb02" executers="bodbLicenseeNet" viewers="" isFunction="0" isNested="0"></info>*/

ALTER PROCEDURE [dbo].[Lrf_BetList_RNG_Detail]
	@AgentList		VARCHAR(MAX),
	@CustId			INT,
	@RefNo			BIGINT,
	@TransType		TINYINT			= 0,
	@MoveBetsDay	SMALLDATETIME,
	@BalanceUpDay	SMALLDATETIME,
	@BaseCurrency	VARCHAR(10)
AS

/*
	Created: Kos@20150921
	Task: Get ticket detail from table bettransRnG (Microgaming RNG Game)
	DB: DBEXT.bodb02
	Original:
	Revisions:
		- 20150924@Kos: Add column BetCheck to return TranId3rd for showing ticket result
		- 20151029@Kos: Change SportType of Microgaming RNG Casino
		- 20151223@Kos: Support RNG Casino Single Wallet and use SportBettypeMatrix [Redmine: #48958]
		- 20160406@Kos: Support Voidbridge [#Redmine: 54925]
		- 20160530@Kos: Add ORDER BY statement to correct ticket order [Redmine: #58448]
		- 20160727@Kos: Include Void/Rejected detail tickets view drilldown WON/LOSE/DRAW summary tickets
					- Change to use inline function for SportBetTypeMatrix
		- 20161111@Kos: Support Fishing World [#Redmine: 66737]
		- 20170307@Kos: Support sub licensees [#Redmine: 71679]
		- 20180514@Kos: Return ExchangeId instead of CurrencyCode [#Redmine: 94845]
		- 20180525@Kos: Support Pragmatic Casino [#Redmine: 92318]
		- 20190321@Kos: Support Pragmatic Promotion Prize [#Redmine: 109471]
		- 20190401@Kos: Don't support Microgaming RNG Casino anymore [#Redmine: 107704]
		- 20190524@Kos: Add new input param @BaseCurrency [#Redmine: 112531]
		- 20190704@Kos: Support Card Club [Redmine: #115449]
		- 20191209@Kos: Support Spadegaming [Redmine: #124103]
		- 20200419@Kos: Support Saba.club [Redmine: #132702]
		- 20200714@Kos: Support PP Jackpot [Redmine: #137290]
					- Return additional column OddsSpread MONEY, BetdaqId BIGINT, ExtraInfo VARCHAR(1000)
		- 20200731@Kos: Support Saba.club Result [Redmine: #137680]
		- 20200815@Kos: Support PG Soft [Redmine: #139182]
		- 20200922@Kos: Support Joker [Redmine: #141408]
		- 20210118@Kos: Support Saba.club Jackpot Contribution and Jackpot Prize tickets [Redmine: #148100]
		- 20210301@Kos: Add BDT and INR as base currencies [Redmine: 150375]
		- 20210524@Kos: Support Vgaming [Redmine: #151583]
		- 20210624@Kos: Support CG [Redmine: #152619]
		- 20210929@Kos: Extend length to support IPv6 [Redmine: 162342]
		- 20211029@Kos: Decompress IP in bk range [Redmine: 162342]
					- Add new params @MoveBetsDay SMALLDATETIME and @BalanceUpDay SMALLDATETIME
		- 20211102@Kos: Support AdvantPlay and AdvantPlay Mini [Redmine: #158186]
		- 20220113@Kos: Support new 3rd result API [Redmine: #166047]
		- 20220215@Kos: Hotfix - Vgaming result [Redmine: #168552]
		- 20220217@Kos: Support SG Jackpot [Redmine: #167035]
		- 20220401@Kos: Support TxId for Vgaming [Redmine: #170054]
		- 20220527@Kos: Support MaxGame [RedmineID: #172919]

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
	WHERE RefTable = 1 AND ProductID NOT IN (17, 50)

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
		BetCheck		VARCHAR(64),
		MatchCode		VARCHAR(1000),
		BetTeam			NVARCHAR(100),
		OddsSpread		MONEY,
		BetdaqId		BIGINT,
		ExtraInfo		VARCHAR(1000),
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
				WHEN sbt.productID IN (24, 32, 34, 66) THEN brng.Additional
				WHEN sbt.productID IN (42) THEN ISNULL(brng.SiteID, '')
				ELSE ''
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
			CASE
				WHEN sbt.ProductID IN (32, 36, 42, 66) THEN ISNULL(brng.JackpotInfo, '')
				ELSE ''
			END AS ExtraInfo,
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
	ELSE IF EXISTS ( SELECT 1 FROM dbo.bettrans14 WITH (NOLOCK) WHERE transid = @RefNo AND winlostdate BETWEEN @BalanceUpDay AND @MoveBetsDay )
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
				WHEN sbt.productID IN (24, 32, 34, 66) THEN brng.Additional
				WHEN sbt.productID IN (42) THEN ISNULL(brng.SiteID, '')
				ELSE ''
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
			CASE
				WHEN sbt.ProductID IN (32, 36, 42, 66) THEN ISNULL(brng.JackpotInfo, '')
				ELSE ''
			END AS ExtraInfo,
			ISNULL(brng.SiteID, '') AS SiteId,
			CASE
				WHEN sbt.productID IN (60) THEN brng.Transdate3rd
				ELSE ''
			END AS EventDate
		FROM dbo.bettransRnG14 AS brng WITH (NOLOCK)
			INNER JOIN @SportBettype AS sbt ON brng.gameID = sbt.Bettype
		WHERE brng.custid = @CustId AND brng.RefNo = @RefNo
	END
	ELSE IF EXISTS ( SELECT 1 FROM DBARC.bodb_Archive.dbo.bettrans_bk WITH (NOLOCK) WHERE transid = @RefNo )
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
			dp.IP,
			brng.transdesc,
			brng.TranId3rd AS BetCheck,
			CASE
				WHEN sbt.productID IN (24, 32, 34, 66) THEN brng.Additional
				WHEN sbt.productID IN (42) THEN ISNULL(brng.SiteID, '')
				ELSE ''
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
			CASE
				WHEN sbt.ProductID IN (32, 36, 42, 66) THEN ISNULL(brng.JackpotInfo, '')
				ELSE ''
			END AS ExtraInfo,
			ISNULL(brng.SiteID, '') AS SiteId,
			CASE
				WHEN sbt.productID IN (60) THEN brng.Transdate3rd
				ELSE ''
			END AS EventDate
		FROM DBARC.bodb_Archive.dbo.bettransRnG_bk AS brng WITH (NOLOCK)
			INNER JOIN @SportBettype AS sbt ON brng.gameID = sbt.Bettype
			CROSS APPLY dbo.f_IP_Decompress(brng.ip) AS dp
		WHERE brng.custid = @CustId AND brng.RefNo = @RefNo
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
	FROM dbo.custinfo AS c WITH (NOLOCK)
	WHERE c.custid = @CustId
		AND c.currency IN (SELECT DISTINCT Currency FROM @TempAg)

	IF @BaseCurrency <> ''
	BEGIN
		INSERT INTO @ExchangeRate
		SELECT
			e.FromDate,
			e.ToDate,
			e.Rate
		FROM dbo.Lrf_f_GetExchangeRate(@ExFromDate, @ExToDate, @BaseCurrency, '') AS e
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
		b.Stake * ISNULL(e.Rate, 1) AS Stake,
		b.Actual_Stake,
		b.WinLost * ISNULL(e.Rate, 1) AS WinLost,
		b.LicenseeWL * ISNULL(e.Rate, 1) AS LicenseeWL,
		b.Comm * ISNULL(e.Rate, 1) AS Comm,
		b.PlayerComm * ISNULL(e.Rate, 1) AS PlayerComm,
		b.Ip,
		b.TransDesc,
		b.BetCheck,
		b.MatchCode,
		b.BetTeam,
		b.OddsSpread,
		b.BetdaqId,
		b.ExtraInfo,
		@Currency AS Currency,
		b.SiteId,
		b.EventDate
	FROM @tmpBettransRnG AS b
		LEFT JOIN @ExchangeRate AS e ON b.WinLostDate BETWEEN e.FirstExchangeDateByMonth AND e.LastExchangeDateByMonth
	ORDER BY b.TransId ASC
END
GO
