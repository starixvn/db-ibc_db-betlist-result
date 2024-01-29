/*<info serverAlias="DBEXT-bodb02" executers="bodbLicenseeNet" viewers="" isFunction="0" isNested="0"></info>*/

ALTER PROCEDURE [dbo].[Lrf_BetList_LiveReport_SelWinlossByMatch]
	@AgentList		VARCHAR(MAX),
	@ProductList	VARCHAR(500),
	@ShowBA			BIT				= 0,
	@MatchId		INT,
	@FromDate		SMALLDATETIME,
	@ToDate			SMALLDATETIME,
	@MoveBetsDay	SMALLDATETIME,
	@LiveIndicator	INT				= 1,
	@BaseCurrency	VARCHAR(12),
	@PageSize		INT				= 1000,
	@PageIndex		INT				= 1
AS

/*
	Created: 20120111@Henry
	Task: Betlist
	DB: DBEXT.bodb02

	Revisions:
		Get all tickets for a match
		- 20120214@Jim: change to use table ExchangeDaily by use function Lrf_f_GetExchangeDaily
		- 20120614@Jim: optimize code
		- 20120724@Jim: add playercomm value
		- 20120820@Jim: add livecasino
		- 20120913@Jim: add virtual sport
		- 20121004@Jim: replace @currency input param by @currencyID
		- 20121115@Henry: Only Sportsbook needs to exclude BA
		- 20130411@Jim: support base currency USD
		- 20130514@Jim: Restrict permission of Licensee Users by currency
		- 20130625@Jim: support to view currency UUS
		- 20140602@Hannah: Separate Live/ Non - Live data in Live Report
		- 20140630@Hannah: offer BetRadar and Sporting Solution
		- 20140925@Jim: restrict Virtual Horse Racing bettype (hot fix  #22012)
		- 20141111@Winnie: change from LicenseeCust to f_SelLicenseeCust
		- 20150124@Winnie: add base currency GBP
		- 20150413@Winnie: Apply spottype bettype matrix & add 60 bettype betradar
		- 20150608@Edward: Exclude 3 transactions SOLD/BOUGHT/BetTrade Commission of BetTrade
		- 20150609@Edward: Support Microgaming
		- 20150922@Kos: Don't support Microgaming anymore
		- 20151203@Kos: Change odds, modds data type from SMALLMONEY to MONEY [Redmine: #48660]
		- 20160201@Kos: Support PH All In One 1.2 [#Redmine: 50897]
		- 20160714@Kos: Change to use inline function for SportBettypeMatrix
		- 20160801@Kos: Exclude bet type 904 [#Redmine: 58978]
		- 20161005@Kos: Add product bet type range for sub tickets [Redmine: #65045]
		- 20170301@Kos: Support sub licensees [#Redmine: 71679]
		- 20170303@Kos: Support KickOffTime for Virtual Soccer and Virtual Tennis [#Redmine: 71906]
		- 20170327@Kos: Support CashOut [#Redmine: 71963]
		- 20170620@Kos: Support Betradar Virtual Sports [#Redmine: 77280]
		- 20170830@Kos: Support Licensee Bonus System [#Redmine: 72792]
		- 20180305@Kos: Don't support Live Casino anymore [#Redmine: 85965]
		- 20180327@Kos: Increase TransDesc length to 1000 [#Redmine: 92433]
		- 20180329@Kos: Support Fast Market 2 [#Redmine: 90879]
		- 20181031@Patrick: DB052 indexes revolution [RedmineID: #103572]
		- 20190509@Kos: Show match KO time for single ticket [Redmine: #112731]
					- Return additional column EventDate DATETIME
		- 20190523@Kos: Add new input param @BaseCurrency [#Redmine: 112531]
		- 20191011@Kos: Support drop table LicenseeBATransaction [Redmine: #103656]
		- 20200207@Kos: Support sort by trans time [Redmine: #126886]
		- 20200425@Kos: Support status Delay Payout [Redmine: #132629]
		- 20210301@Kos: Add BDT and INR as base currencies [Redmine: 150375]
		- 20210916@Kos: Support Cricket [Redmine: 160452]
					- Add new input params @FromDate SMALLDATETIME, @ToDate SMALLDATETIME, @MoveBetsDay SMALLDATETIME
		- 20210929@Kos: Extend length to support IPv6 [Redmine: 162342]
		- 20211125@Kos: Hotfix - Timeout in bettrans14 range [Redmine: 165188]
		- 20211220@Kos: Support new Cash Out [Redmine: #165160]
		- 20220110@Kos: Support TxId for 3rd products [Redmine: #166706]
		- 20220922@Kos: Support crypto currency [Redmine: 177481]
		- 20230803@Kos: Support Virtual Sports 3 [Redmine: 190908]
		- 20240129@Kos: Merge VS1, VS2, VS3 into VS [Redmine: 199523]
					- Remove input params @ShowSB, @ShowVS, @ShowVS2, @ShowLG
					- Add new input param @ProductList VARCHAR(500)

	Param's Explanation: 
		@LiveIndicator : indicate that whether the report will get live data or not
			+ 0: Non - Live data only
			+ 1: Live data only
			+ 2: All
*/

BEGIN
	SET NOCOUNT ON

	CREATE TABLE #TempAg (CustId INT, Currency INT)

	CREATE CLUSTERED INDEX IX_CustId ON #TempAg (CustId)

	-- Get AgentList
	DECLARE @DocHandler INT

	BEGIN TRY
		EXEC sp_xml_preparedocument @DocHandler OUTPUT, @AgentList
	
		INSERT INTO #TempAg (CustId, Currency)
		SELECT AgentId, Currency
		FROM OPENXML(@DocHandler, '/ROOT/Agent', 1) WITH (AgentId INT, Currency INT) AS Data

		EXEC sp_xml_removedocument @DocHandler
	END TRY
	BEGIN CATCH
		SELECT ErrCode = 100,
			ErrMsg = N'Parameter invalid.'

		RETURN
	END CATCH

	DECLARE @ShowSB	BIT = 0

	IF ',' + @ProductList + ',' LIKE '%,SB,%'
		SET @ShowSB = 1

	IF @ShowBA = 1
		SET @ProductList = @ProductList + ',SB'

	-- Get child product list
	IF EXISTS (SELECT 1 FROM dbo.Lrf_f_GroupProduct() WHERE ',' + @ProductList + ',' LIKE '%,' + GroupProductPrefix + ',%')
	BEGIN
		DECLARE @ChildProductList VARCHAR(500)

		SELECT @ChildProductList = STRING_AGG(ProductPrefix, ',')
		FROM dbo.Lrf_f_GroupProduct()
		WHERE ',' + @ProductList + ',' LIKE '%,' + GroupProductPrefix + ',%'

		SET @ProductList = @ProductList + ',' + @ChildProductList
	END

	-- Get Sport Bettype Matrix
	DECLARE @SportBettype TABLE(ProductId TINYINT, BetType SMALLINT, EventType TINYINT)

	DECLARE @IsTest BIT = 0

	SELECT @IsTest = dbo.f_CheckSPVersion(@@PROCID)

	INSERT INTO @SportBettype
	SELECT ProductID, BetType, EventType
	FROM dbo.f_SportBettypeMatrix_Sel (0, 0, 0, 2, '', @ProductList, @IsTest)
	WHERE EventType = 1
		AND BetType NOT IN (901, 902, 903, 904)
		AND BetType NOT BETWEEN 801 AND 899

	DECLARE @RowStart INT, @RowEnd INT

	SELECT @PageIndex = @PageIndex - 1,
		@RowStart = @PageSize * @PageIndex + 1,
		@RowEnd = @RowStart + @PageSize - 1

	CREATE TABLE #Data (
		SportType			INT,
		Username			NVARCHAR(50),
		CustId				INT,
		BetType				INT,
		LeagueId			INT,
		TransId				BIGINT,
		BATransId			BIGINT,
		MatchCode			VARCHAR(50),
		EventDate			DATETIME,
		HomeId				INT,
		AwayId				INT,
		Hdp1				SMALLMONEY,
		Hdp2				SMALLMONEY,
		Odds				MONEY,
		Status				NVARCHAR(50),
		SettlementStatus	TINYINT,
		Stake				MONEY,
		Actual_Stake		MONEY,
		WinLost				MONEY,
		LicenseeWL			MONEY,
		Comm				MONEY,
		PlayerComm			MONEY,
		TransDate			DATETIME,
		WinLostDate			DATETIME,
		BetTeam				VARCHAR(50),
		LiveIndicator		INT,
		LiveHomeScore		SMALLINT,
		LiveAwayScore		SMALLINT,
		MatchId				INT,
		Ip					VARCHAR(45),
		BetStatus			NVARCHAR(50),
		IsNeutral			BIT,
		OddsType			INT,
		BetId				BIGINT,
		Currency			SMALLINT,
		RefNo				BIGINT,
		ShowTime			NVARCHAR(50),
		BetCheck			NVARCHAR(50),
		TransDesc			NVARCHAR(1000),
		BetdaqId			BIGINT,
		ExtraInfo			VARCHAR(1000),
		OriginalStake		MONEY,
		OriginalBetType		SMALLINT,
		WalletType			TINYINT,
		RefCode				BIGINT,
		OddsSpread			MONEY
	)

	CREATE TABLE #ExchangeRate (
		ExchangeId					INT,
		FirstExchangeDateByMonth	SMALLDATETIME,
		LastExchangeDateByMonth		SMALLDATETIME,
		Rate						FLOAT
	)
	DECLARE @MatchSportType	SMALLINT,
			@ParentId			INT

	SELECT
		@MatchSportType = sporttype,
		@ParentId = ParentID
	FROM dbo.match WITH (NOLOCK)
	WHERE matchid = @MatchId AND eventdate > @MoveBetsDay

	IF @MatchSportType IS NULL
	BEGIN
		SELECT
			@MatchSportType = sporttype,
			@ParentId = ParentID
		FROM dbo.match14 WITH (NOLOCK)
		WHERE matchid = @MatchId
	END

	DECLARE @Match TABLE (MatchId INT)

	INSERT INTO @Match
	SELECT @MatchId

	IF @MatchSportType = 50 AND @ParentId IS NULL	-- Cricket, parent match
	BEGIN
		INSERT INTO @Match
		SELECT DISTINCT
			MatchId
		FROM dbo.match WITH (NOLOCK)
		WHERE ParentID = @MatchId
			AND sporttype = @MatchSportType
			AND eventdate BETWEEN @FromDate AND @ToDate
			AND ChildMatchType = 200
		UNION
		SELECT DISTINCT
			MatchId
		FROM dbo.match14 WITH (NOLOCK)
		WHERE ParentID = @MatchId
			AND sporttype = @MatchSportType
			AND eventdate BETWEEN @FromDate AND @ToDate
			AND ChildMatchType = 200
	END

	IF EXISTS (SELECT TOP(1) 1 FROM dbo.match WITH (NOLOCK) WHERE matchid = @MatchID)
	BEGIN
		INSERT INTO #Data
		SELECT
			m.sporttype,
			b.username,
			b.custid,
			b.bettype,
			m.leagueid,
			b.transid,
			ba.TransID AS BATransId,
			m.matchcode,
			m.GlobalShowTime AS EventDate,
			m.homeid,
			m.awayid,
			b.hdp1,
			b.hdp2,
			b.odds,
			b.status,
			ISNULL(m.SettlementStatus, 0) AS SettlementStatus,
			b.stake,
			b.actual_stake,
			(b.winlost - b.actual_stake) AS WinLost,
			0 AS LicenseeWL,
			b.comm,
			b.playercomm,
			b.transdate,
			b.winlostdate,
			b.betteam,
			b.liveindicator,
			b.livehomescore,
			b.liveawayscore,
			b.matchid,
			b.ip,
			m.betstatus,
			ISNULL(m.IsNeutral, CONVERT(BIT, 0)) AS IsNeutral,
			b.oddstype,
			b.betid,
			b.currency,
			b.refno,
			'' AS ShowTime,
			b.betcheck,
			ISNULL(b.transdesc, '') AS transdesc,
			ISNULL(b.betdaqid, -1) AS BetdaqId,
			ISNULL(b.ExtraInfo, '') AS ExtraInfo,
			CASE
				WHEN b.ExtraInfo LIKE '%p25%' THEN
					ISNULL(CAST(('<xml>' + b.ExtraInfo + '</xml>') AS XML).value('data(/xml/p25/@s)[1]','MONEY'), 0)
				ELSE 0
			END AS OriginalStake,
			CASE
				WHEN b.stake <> 0 THEN -1
				ELSE 0
			END AS OriginalBetType,
			0 AS WalletType,
			0 AS RefCode,
			ISNULL(b.oddsspread, 0) AS OddsSpread
		FROM
			dbo.bettrans AS b WITH (NOLOCK)
			INNER JOIN #TempAg AS ta ON ta.CustId = b.recommend
			INNER JOIN @SportBettype AS sbt ON b.Bettype = sbt.Bettype
			INNER JOIN @Match AS tm ON tm.MatchId = b.matchid
			INNER JOIN dbo.match AS m ON m.matchid = tm.MatchId
			LEFT JOIN bodb_licensee.dbo.LicenseeBATransaction_active AS BA WITH (NOLOCK) ON b.transid = BA.transid
		WHERE b.statusID IN (111, 112, 113)
			AND ((@LiveIndicator = 0 AND b.liveindicator = 0)
				OR (@LiveIndicator = 1 AND b.liveindicator = 1)
				OR (@LiveIndicator = 2))
	END
	ELSE
	BEGIN
		INSERT INTO #Data
		SELECT
			m.sporttype,
			b.username,
			b.custid,
			b.bettype,
			m.leagueid,
			b.transid,
			ba.TransID AS BATransId,
			m.matchcode,
			m.GlobalShowTime AS EventDate,
			m.homeid,
			m.awayid,
			b.hdp1,
			b.hdp2,
			b.odds,
			b.status,
			0 AS SettlementStatus,
			b.stake,
			b.actual_stake,
			(b.winlost - b.actual_stake) AS WinLost,
			0 AS LicenseeWL,
			b.comm,
			b.playercomm,
			b.transdate,
			b.winlostdate,
			b.betteam,
			b.liveindicator,
			b.livehomescore,
			b.liveawayscore,
			b.matchid,
			b.ip,
			m.betstatus,
			ISNULL(m.IsNeutral, CONVERT(BIT, 0)) AS IsNeutral,
			b.oddstype,
			b.betid,
			b.currency,
			b.refno,
			'' AS ShowTime,
			b.betcheck,
			ISNULL(b.transdesc, '') AS transdesc,
			ISNULL(b.betdaqid, -1) AS BetdaqId,
			ISNULL(b.ExtraInfo, '') AS ExtraInfo,
			CASE
				WHEN b.ExtraInfo LIKE '%p25%' THEN
					ISNULL(CAST(('<xml>' + b.ExtraInfo + '</xml>') AS XML).value('data(/xml/p25/@s)[1]','MONEY'), 0)
				ELSE 0
			END AS OriginalStake,
			CASE
				WHEN b.stake <> 0 THEN -1
				ELSE 0
			END AS OriginalBetType,
			0 AS WalletType,
			0 AS RefCode,
			ISNULL(b.oddsspread, 0) AS OddsSpread
		FROM
			dbo.bettrans14 AS b WITH (NOLOCK)
			INNER JOIN #TempAg AS ta ON ta.CustId = b.recommend
			INNER JOIN @SportBettype AS sbt ON b.Bettype = sbt.Bettype
			INNER JOIN @Match AS tm ON tm.MatchId = b.matchid
			INNER JOIN dbo.match14 AS m ON m.matchid = tm.MatchId
			LEFT JOIN bodb_licensee.dbo.LicenseeBATransaction_bk AS BA WITH (NOLOCK) ON b.transid = BA.transid
		WHERE b.statusID IN (111, 112, 113)
			AND ((@LiveIndicator = 0 AND b.liveindicator = 0)
				OR (@LiveIndicator = 1 AND b.liveindicator = 1)
				OR (@LiveIndicator = 2))
	END

	DELETE #Data
	WHERE (@ShowSB = 0
			AND BetType IN (9, 29)
			AND BATransId IS NULL)
		OR (@ShowBA = 0
			AND BetType IN (9, 29)
			AND BATransId IS NOT NULL)

	-- Get data for summary ticket of multiple Bonus/Cash sub tickets
	IF EXISTS (SELECT 1 FROM #Data WHERE RefCode <> 0)
	BEGIN
		DECLARE @RefCodeTmp TABLE (
			RefCode			BIGINT,
			TransId			BIGINT,
			Stake			MONEY,
			Actual_Stake	MONEY,
			WinLost			MONEY,
			LicenseeWL		MONEY,
			Comm			MONEY,
			PlayerComm		MONEY
		)

		-- Prepare temp table
		INSERT INTO @RefCodeTmp
		SELECT
			RefCode,
			MIN(TransId) AS TransId,
			SUM(Stake) AS Stake,
			SUM(Actual_Stake) AS Actual_Stake,
			SUM(WinLost) AS WinLost,
			SUM(LicenseeWL) AS LicenseeWL,
			SUM(Comm) AS Comm,
			SUM(PlayerComm) AS PlayerComm
		FROM #Data
		WHERE RefCode <> 0
		GROUP BY RefCode
		HAVING COUNT(*) > 1

		IF EXISTS (SELECT 1 FROM @RefCodeTmp)
		BEGIN
			-- Update data for summmary ticket
			UPDATE b
			SET
				b.Stake = r.Stake,
				b.Actual_Stake = r.Actual_Stake,
				b.WinLost = r.WinLost,
				b.LicenseeWL = r.LicenseeWL,
				b.Comm = r.Comm,
				b.PlayerComm = r.PlayerComm,
				b.WalletType = 0
			FROM #Data AS b
				INNER JOIN @RefCodeTmp AS r ON b.RefCode = r.RefCode AND b.TransId = r.TransId

			-- Delete 2nd Bonus/Cash tickets
			DELETE #Data
			WHERE WalletType <> 0
				AND RefCode IN (SELECT RefCode FROM @RefCodeTmp)
		END
	END

	-- Display detail link for ticket from Bonus Wallet only
	UPDATE #Data
	SET RefCode = TransId
	WHERE WalletType = 1 AND RefCode = 0

	-- Don't display Cash text for ticket from Cash Wallet only
	UPDATE #Data
	SET WalletType = 0
	WHERE WalletType = 2 AND RefCode = 0

	-- Get exchange rate
	DECLARE @Today SMALLDATETIME
 
	SET @Today = CONVERT(VARCHAR(10), CURRENT_TIMESTAMP, 120)

	DECLARE @ExFromDate SMALLDATETIME,
		@ExToDate SMALLDATETIME

	SELECT
		@ExFromDate = MIN(WinLostDate),
		@ExToDate = MAX(WinLostDate)
	FROM #Data

	INSERT INTO #ExchangeRate
	SELECT
		e.ExchangeId,
		e.FromDate,
		e.ToDate,
		e.Rate
	FROM dbo.Lrf_f_GetExchangeRate(@ExFromDate, @ExToDate, @BaseCurrency, '') AS e
	WHERE EXISTS (SELECT 1 FROM #Data
				WHERE Currency = e.ExchangeId
					AND WinLostDate BETWEEN e.FromDate AND e.ToDate)

	SELECT A.* 
	FROM
		(
			SELECT
				ROW_NUMBER() OVER(ORDER BY b.TransDate ASC) AS RowNum,
				b.SportType,
				b.Username,
				SUBSTRING(c.username2,  CHARINDEX('$', c.username2) + 1, LEN(c.username2) - CHARINDEX('$', c.username2)) AS Nickname,
				b.CustId,
				b.BetType,
				b.LeagueId,
				b.TransId,
				b.MatchCode,
				b.EventDate,
				b.HomeId,
				b.AwayId,
				b.Hdp1,
				b.Hdp2,
				b.Odds,
				b.Status,
				b.SettlementStatus,
				b.Stake * ISNULL(e.Rate, 1) AS Stake,
				b.Actual_Stake * ISNULL(e.Rate, 1) AS Actual_Stake,
				b.WinLost * ISNULL(e.Rate, 1) AS WinLost,
				b.LicenseeWL * ISNULL(e.Rate, 1) AS LicenseeWL,
				b.Comm * ISNULL(e.Rate, 1) AS Comm,
				b.PlayerComm * ISNULL(e.Rate, 1) AS PlayerComm,
				b.TransDate,
				b.WinLostDate,
				b.BetTeam,
				b.LiveIndicator,
				b.LiveHomeScore,
				b.LiveAwayScore,
				b.MatchId,
				b.Ip,
				b.BetStatus,
				b.IsNeutral,
				b.OddsType,
				b.BetId,
				b.Currency,
				b.RefNo,
				b.ShowTime,
				b.BetCheck,
				b.TransDesc,
				b.BetdaqId,
				b.ExtraInfo,
				b.OriginalStake * ISNULL(e.Rate, 1) AS OriginalStake,
				b.OriginalBetType,
				b.WalletType,
				b.RefCode,
				b.OddsSpread
			FROM #Data AS b
				INNER JOIN dbo.Customer AS c WITH (NOLOCK) ON b.CustId = c.custid
				LEFT JOIN #ExchangeRate AS e
			ON e.ExchangeId = b.Currency
				AND CASE
						WHEN b.WinLostDate > @Today THEN @Today
						ELSE b.WinLostDate
					END BETWEEN e.FirstExchangeDateByMonth AND e.LastExchangeDateByMonth
		) A
	WHERE A.RowNum BETWEEN @RowStart AND @RowEnd

	DROP TABLE #TempAg
	DROP TABLE #Data
	DROP TABLE #ExchangeRate
END
GO
