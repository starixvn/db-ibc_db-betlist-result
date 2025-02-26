/*<info serverAlias="DBBOF-bodb02" executers="wsv_lap" viewers="" isFunction="0" isNested="0"></info>*/

ALTER PROCEDURE [dbo].[Lrf_Monitor_BetlistSel_New]
	@AgentList			VARCHAR(MAX),
	@ProductList		VARCHAR(100)	= '',
	@BetType			VARCHAR(50)		= '',
	@Currency			VARCHAR(200)	= '',
	@SpecialLevel		VARCHAR(200)	= '',
	@TransId			BIGINT			= 0,
	@TransLogId			BIGINT			= 0,
	@LimitRowCount		INT				= 10,
	@SportTypeList		VARCHAR(MAX)	= 'All',
	@LeagueList			VARCHAR(MAX)	= 'All',
	@MatchId			INT				= 0,
	@MinStake			MONEY			= 0,
	@MaxStake			MONEY			= 0,
	@LiveIndicator		INT				= 0,
	@BetFrom			VARCHAR(200)	= 'All',
	@CustomerClass		VARCHAR(MAX)	= 'All',
	@FullCustomerClass	VARCHAR(MAX)	= 'All',
	@BaseCurrency		VARCHAR(12)		='USD',
	@Debug				BIT				= 0
AS

/*
	Created: Scott@20130418
	Task: LRF Monitor lastest bets list(all bettypes and all sports) with filter by League and Sport
	DB: DBBOF.bodb02

	Revision:
		- 20130618@Jim: Restrict permission of Licensee Users by currency
		- 20130806@Jim: Add betting platform to Last bets monitoring
		- 20140620@Florent: Offer Sporting Solution (36 new bettypes)
		- 20141021@Florent: Apply for the change in Sporting Solution structure (#24478)
		- 20141120@Jim: Expand data range for @TransId param to covert big datatype
		- 20150128@Jim: base on GBP
		- 20150415@Jim: Support betradar
		- 20151210@Kos: Support PH All In One 4 new bet types 401, 402, 403, 404 (O/U bettypes)
		- 20160115@Joseph: Redefine values of parameter betfrom
		- 20160413@Kos: Support Combo Parlay [#Redmine: 55282]
		- 20160919@Kos: Add column transdesc to support PH AIO phase 2b [#Redmine: 62878]
		- 20170307@Kos: Support sub licensees [#Redmine: 71679]
		- 20170331@Kos: Support CashOut [#Redmine: 71963]
		- 20170419@Kos: Support BAIO [#Redmine: 73030]
		- 20170803@Kos: Support more betfrom value [#Redmine: 80687]
		- 20170920@Kos: Support new bet types 461-464 [#Redmine: 83260]
		- 20171020@Kos: Support new platform New Asia [#Redmine: 85203]
		- 20171031@Kos: Support Licensee Bonus System [#Redmine: 72792]
		- 20180319@Kos: Support Fast Market 2 [#Redmine: 90879]
		- 20180817@Kos: Migrate to DB042 [RedmineID: #99464]
		- 20180823@Kos: HotFix - Miss SpecialLevel [RedmineID: #100423]
		- 20180903@Kos: Remove dynamic SQL [RedmineID: #101703]
					- Remove param @IncludeBetFrom
					- Change base currency coding style, support all base currencies
		- 20181114@Kos: Change getting ticket status [#Redmine: 104664]
		- 20181121@Kos: Support new platform 'o' Mobile App [#Redmine: 104521]
		- 20181210@Kos: Support new platform 'c' Mobile China View [#Redmine: 106088]
		- 20190107@Kos: Support Parlay Changes [#Redmine: 107165]
		- 20190520@Kos: Support more base currency [#Redmine: 112531]
		- 20191216@Kos: Support betfrom Licensee Odds Feed 'v' [Redmine: #125553]
		- 20191226@Kos: Support betfrom Native Apps '0' [Redmine: #125824]
		- 20200207@Kos: Support sort by trans time [Redmine: #126886]
		- 20200302@Kos: Support 3 new betfrom [Redmine: #129253]
		- 20200619@Kos: Support 3 new eGamer betfrom [Redmine: #136107]
		- 20201007@Kos: Support Time Machine Over/Under [Redmine: #136107]
		- 20201207@Kos: Hotfix - Wrong currency code display [Redmine: #146691]
		- 20210122@Kos: Support betfrom '7' [Redmine: #149108]
		- 20210301@Kos: Add BDT and INR as base currencies [Redmine: 150375]
		- 20210309@Kos: Support betfrom '_', '@', '%' [Redmine: #151019]
		- 20210315@Kos: Support Cricket AIO [Redmine: #148962]
		- 20210323@Kos: Support show IP [Redmine: #151085]
		- 20210325@Kos: Support betfrom '8', '9' [Redmine: #152158]
		- 20210414@Razor: Support Time Machine HDP [Redmine: #152749]
		- 20210518@Kos: Support multiple selection on Platform filter [Redmine: #153102]
		- 20210929@Kos: Extend length to support IPv6 [Redmine: 162342]
		- 20211104@Kos: Merge Sports Lottery into Sportsbook [RedmineID: #163191]
					- Add new input param @ProductList VARCHAR(100), @TransLogId BIGINT
					- Return additional column SportType SMALLINT
		- 20220302@Kos: Support filter by Customer Class [RedmineID: #167824]
					- Remove input params SportId and LeagueId
					- Add new input params @SportTypeList VARCHAR(MAX), @LeagueList VARCHAR(MAX), @CustomerClass VARCHAR(200)
		- 20220428@Kos: Support Bitcoin [RedmineID: #160160]
		- 20220811@Kos: Support Customer Class Is NULL [RedmineID: #176156]
		- 20220825@Kos: Hotfix - Extend length for Customer Class [RedmineID: #177077]
		- 20220922@Kos: Support crypto currency [Redmine: 177481]
		- 20221207@Kos: Support Saba E-Sports PinGoal [RedmineID: #181224]
		- 20230404@Kos: Extend betfrom length [Redmine: #178059]
		- 20230703@Kos: Support Saba Tennis [RedmineID: #190465]
		- 20231127@Kos: Support Jollysports [RedmineID: #197192]
		- 20240207@Kos: Hotfix - No data when filtering player has Risk Level Uncategorized [RedmineID: #200913]
					- Add new input param @FullCustomerClass VARCHAR(MAX)
		- 20240307@Kos: Support Saba Ice Hockey [RedmineID: #201283]
		- 20240412@Kos: Support Gaming API [Redmine: 203734]
		- 20240509@Kos: Support Saba Kabaddi [RedmineID: #203612]
		- 20241210@Kos: Add unknown betfroms into group Others [#Redmine: 214849]
		- 20250225@Kos: Fix bug FLOAT rounding [#Redmine: 194970]

	Parameter's Explanation:
		- @BetType:
			+ HDP: 1, 7, 1303, 17, 183, 609, 229
			+ OU: 3, 18, 8, 178, 1306, 401, 402, 403, 404, 461, 462, 463, 464, 610, 615, 616, 228
			+ Others: NOT IN 1, 3, 7, 8, 17, 18, 178, 183, 1303, 1306, 401, 402, 403, 404, 461, 462, 463, 464
			+ ALL: <= 19000
		- @TransId: latest transid
		- @LimitRowCount: max record return (10,20,30)
		- @SportTypeList: 
			+ All: all sport types
			+ XML format
				<ROOT>
					<Sport SportType="1" LeagueGroupIds="0"/>
					<Sport SportType="1" LeagueGroupIds="42,74"/>
					<Sport SportType="5" LeagueGroupIds="0"/>
					<Sport SportType="999" LeagueGroupIds="0"/>
				</ROOT>
				+ Parlay: <Sport SportType="999" LeagueGroupIds="0"/>
				+ Sports Lottery: <Sport SportType="169" LeagueGroupIds="0"/>
				+ Saba Soccer: <Sport SportType="1" LeagueGroupIds="42,74"/>
				+ Saba Soccer PinGoal: <Sport SportType="1" LeagueGroupIds="113"/>
				+ Saba Basketball: <Sport SportType="2" LeagueGroupIds="42"/>
				+ Saba Basketball PinGoal: <Sport SportType="2" LeagueGroupIds="122"/>
				+ Saba Cricket: <Sport SportType="50" LeagueGroupIds="42"/>
				+ Saba Futsal: <Sport SportType="1" LeagueGroupIds="108"/>
				+ Saba E-Sports PinGoal: <Sport SportType="43" LeagueGroupIds="151"/>
				+ Saba Tennis: <Sport SportType="5" LeagueGroupIds="42"/>
				+ Saba Ice Hockey: <Sport SportType="4" LeagueGroupIds="42"/>
				+ Saba Kabaddi: <Sport SportType="47" LeagueGroupIds="42"/>
		- @LiveIndicator (0 : non live, 1 : live , 2 : mix non live & live)
		- @IncludeBetFrom: 1: show column betfrom, 0: hide
		- @BetFrom:
			- All - All: All
			- 1 - Desktop New Asia: x (dep2-Asia)
			- 2 - Desktop China: a (dep-Singbet), z (dep2-SingBet)
			- 3 - Desktop Others: 9 (3rd Party Portal Service - Desktop)
			- 4 - Mobile Standard: l (dep-smart), _ (Quick Bet)
			- 5 - Mobile Euro: % (Mobile Euro)
			- 6 - Mobile Compact: c (dep-MCV), @ (Quick Bet)
			- 7 - Mobile Others: 7 (3rd Party Portal Service - Facebook Wall), 8 (3rd Party Portal Service - Statement AD)
			- 8 - E-Sports Desktop: 1 (E-Sports Web Desktop), 4 (eGamer Desktop)
			- 9 - E-Sports Mobile: 2 (E-Sports Web Mobile), 5 (eGamer Mobile)
			- 10 - E-Sports APP: 3 (E-Sports App), 6 (eGamer App)
			- 11 - Mobile APP: o (dep-New Mobile APP)
			- 12 - Native APP: 0 (Native App)
			- 13 - Tablet: r (dep2-tablet)
			- 14 - Deep Link: t (Licensee-Deeplink)
			- 15 - WAP: m (dep-wap)
			- 88 - Others: v (Licensee Odds Feed), d (mobile), g (MG Download only), e (Europe), u (dep-Euro)
		- @ProductList: SB and all products grouped under SB (SB,SL,...)
		- @LeagueList: list of league seperated by commas (All: all leagues)
		- @CustomerClass: list of customer class seperated by commas (All: all customer classes)
		- @FullCustomerClass: list of all customer class seperated by commas (All: all customer classes)

	Excecute sample :
		[Lrf_Monitor_BetlistSel_New]
			@LicenseeID = 14,
			@BetType='HDP',
			@LicenseeType='Normal',
			@Currency='1,2,3,4,5,6,7,8,9,10',
			@SpecialLevel='0,1,2,3,4,5,6,7,8,9',
			@TransId=0,
			@LimitRowCount=10,
			@SportId=1,
			@LeagueId=3,
			@Matchid=3874470,
			@MinStake=100,
			@LiveIndicator=0
*/

BEGIN
	SET NOCOUNT ON

	DECLARE @HasError BIT = 0
	DECLARE @DocHandler INT

	-- Get AgentList
	CREATE TABLE #TempAg (CustId INT, Currency INT)

	CREATE CLUSTERED INDEX IX_TempAg ON #TempAg (CustId)

	BEGIN TRY
		EXEC sp_xml_preparedocument @DocHandler OUTPUT, @AgentList
	
		INSERT INTO #TempAg (CustId, Currency)
		SELECT AgentId, Currency
		FROM OPENXML(@DocHandler, '/ROOT/Agent', 1) WITH (AgentId INT, Currency INT) AS Data

		EXEC sp_xml_removedocument @DocHandler
	END TRY
	BEGIN CATCH
		SET @HasError = 1
	END CATCH

	-- Get sport type list
	CREATE TABLE #TempSportType (SportType SMALLINT, LeagueGroupIdList VARCHAR(200))

	CREATE CLUSTERED INDEX IX_SportType ON #TempSportType (SportType)

	IF @SportTypeList <> 'All'
	BEGIN TRY
		EXEC sp_xml_preparedocument @DocHandler OUTPUT, @SportTypeList
	
		INSERT INTO #TempSportType (SportType, LeagueGroupIdList)
		SELECT SportType, LeagueGroupIds
		FROM OPENXML(@DocHandler, '/ROOT/Sport', 1) WITH (SportType SMALLINT, LeagueGroupIds VARCHAR(200)) AS Data

		EXEC sp_xml_removedocument @DocHandler
	END TRY
	BEGIN CATCH
		SET @HasError = 1
	END CATCH

	-- Get full sport type list
	DECLARE @FullSportType TABLE (SportType SMALLINT, LeagueGroupIdList VARCHAR(200))

	INSERT INTO @FullSportType
	SELECT 1, '42,74'		-- Saba Soccer
	UNION SELECT 1, '113'	-- Saba Soccer PinGoal
	UNION SELECT 2, '42'	-- Saba Basketball
	UNION SELECT 2, '122'	-- Saba Basketball PinGoal
	UNION SELECT 50, '42'	-- Saba Cricket
	UNION SELECT 1, '108'	-- Saba Futsal
	UNION SELECT 43, '151'	-- Saba E-Sports PinGoal
	UNION SELECT 5, '42'	-- Saba Tennis
	UNION SELECT 4, '42'	-- Saba Ice Hockey
	UNION SELECT 47, '42'	-- Saba Kabaddi

	DECLARE @Data TABLE (
		CustId			INT,
		CustomerClass	SMALLINT,
		MatchId			INT,
		LeagueId		INT,
		LeagueGroupId	SMALLINT,
		SportType		SMALLINT,
		BetType			SMALLINT,
		TransId			BIGINT,
		RefNo			BIGINT,
		TransDate		DATETIME,
		BetId			BIGINT,
		LiveHomeScore	SMALLINT,
		LiveAwayScore	SMALLINT,
		LiveIndicator	INT,
		Hdp1			SMALLMONEY,
		Hdp2			SMALLMONEY,
		Odds			MONEY,
		Actual_Stake	MONEY,
		Stake			MONEY,
		BetFrom			NVARCHAR(4),
		Status			NVARCHAR(10),
		BetTeam			NVARCHAR(10),
		OddsType		TINYINT,
		Ip				VARCHAR(45),
		CurrencyId		SMALLINT,
		SpecialLevel	INT,
		BetCheck		NVARCHAR(100),
		TransDesc		NVARCHAR(1000),
		BetdaqId		BIGINT,
		ExtraInfo		VARCHAR(1000),
		OriginalStake	MONEY,
		OriginalBetType	SMALLINT,
		WalletType		TINYINT,
		RefCode			BIGINT,
		OddsSpread		MONEY,
		ProductId		TINYINT,
		EventType		TINYINT
	)

	DECLARE @ExchangeRate TABLE (
		ExchangeId	INT,
		Rate		FLOAT
	)

	IF @HasError = 0
	BEGIN
		IF @MinStake IS NULL
			SET @MinStake = 0

		IF @MaxStake IS NULL
			SET @MaxStake = 0

		CREATE TABLE #AllPlatformList (BetFrom NVARCHAR(4))
		CREATE TABLE #PlatformList (BetFrom NVARCHAR(4) PRIMARY KEY)

		IF @BetFrom <> 'All'
		BEGIN
			INSERT INTO #AllPlatformList (BetFrom)
			SELECT DISTINCT betfrom
			FROM dbo.Lrf_f_BetFromType_Sel('All')

			INSERT INTO #PlatformList (BetFrom)
			SELECT DISTINCT betfrom
			FROM dbo.Lrf_f_BetFromType_Sel(@BetFrom)
		END

		-- Check if @TransId and @TransId + 1 is combo ticket then reset @TransId
		DECLARE @RefCode	BIGINT

		SELECT @RefCode = RefCode
		FROM dbo.bettrans WITH (NOLOCK)
		WHERE transid = @TransId

		IF @RefCode IS NOT NULL AND @RefCode > 0
		BEGIN
			IF EXISTS (	SELECT 1 FROM dbo.bettrans WITH (NOLOCK)
						WHERE transid = @TransId + 1 AND RefCode = @RefCode )
			BEGIN
				SET @TransId = @TransId + 1
			END
		END

		-- bettrans
		INSERT INTO @Data (
			CustId,
			MatchId,
			SportType,
			BetType,
			TransId,
			RefNo,
			TransDate,
			BetId,
			LiveHomeScore,
			LiveAwayScore,
			LiveIndicator,
			Hdp1,
			Hdp2,
			Odds,
			Actual_Stake,
			Stake,
			BetFrom,
			Status,
			BetTeam,
			OddsType,
			Ip,
			CurrencyId,
			SpecialLevel,
			BetCheck,
			TransDesc,
			BetdaqId,
			ExtraInfo,
			OriginalStake,
			OriginalBetType,
			WalletType,
			RefCode,
			OddsSpread)
		SELECT
			b.custid,
			b.matchid,
			0 AS SportType,
			b.bettype,
			b.transid,
			b.refno,
			b.transdate,
			b.betid,
			b.livehomescore,
			b.liveawayscore,
			b.liveindicator,
			b.hdp1,
			b.hdp2,
			b.odds,
			b.actual_stake,
			b.stake,
			b.betfrom,
			CASE
				WHEN b.bettype NOT IN (9, 29) AND b.status = 'running' AND ISNULL(b.SecAcceptFlag, 0) = 1 AND ISNULL(b.checktime, CURRENT_TIMESTAMP) > CURRENT_TIMESTAMP THEN 'waiting'
				WHEN b.bettype IN (9, 29) AND b.status = 'running' THEN
					CASE
						WHEN EXISTS (SELECT 1 FROM dbo.bettransm AS bm WITH (NOLOCK)
									WHERE bm.custid = b.custid
										AND bm.refno = b.refno
										AND (bm.status = 'waiting'
											OR (bm.status = 'running' AND ISNULL(bm.SecAcceptFlag, 0) = 1 AND ISNULL(bm.checktime, CURRENT_TIMESTAMP) > CURRENT_TIMESTAMP)))
							THEN 'Waiting'
						ELSE b.status
					END
				ELSE b.status
			END AS status,
			b.betteam,
			b.oddstype,
			b.ip,
			b.currency AS CurrencyId,
			0 AS SpecialLevel,
			ISNULL(b.betcheck, '') AS BetCheck,
			ISNULL(b.transdesc, '') AS TransDesc,
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
			ISNULL(b.WalletType, 0) AS WalletType,
			ISNULL(b.RefCode, 0) AS RefCode,
			ISNULL(b.oddsspread, 0) AS OddsSpread
		FROM dbo.bettrans AS b WITH (NOLOCK, INDEX = IX_monitor_recommend)
			INNER JOIN #TempAg AS a ON b.Recommend = a.CustId
			LEFT JOIN #PlatformList AS pl ON pl.BetFrom = b.betfrom
			LEFT JOIN #AllPlatformList AS apl ON apl.BetFrom = b.betfrom
		WHERE b.statusID IN (0, 1)
			AND b.transid > @TransId
			AND (@Currency = ''
				OR ',' + @Currency + ',' LIKE '%,' + CONVERT(VARCHAR(3), b.currency) + ',%')
			AND (@LiveIndicator = 3
				OR (b.bettype IN (9, 29) AND b.livehomescore = @LiveIndicator)
				OR (b.bettype NOT IN (9, 29) AND @LiveIndicator IN (0, 1) AND b.liveindicator = @LiveIndicator))
			AND (@BetType = ''
				OR (@BetType = 'HDP' AND b.bettype IN (1, 7, 1303, 17, 183, 609, 229))
				OR (@BetType = 'OU' AND b.bettype IN (3, 18, 8, 178, 1306, 401, 402, 403, 404, 461, 462, 463, 464, 610, 615, 616, 228, 9604, 7901))
				OR (@BetType = 'Others' AND b.bettype NOT IN (1, 3, 7, 8, 17, 18, 178, 183, 1303, 1306, 228, 401, 402, 403, 404, 461, 462, 463, 464, 609, 610, 615, 616, 9604, 7901)))
			AND 1 = CASE
						WHEN @BetFrom = 'All' THEN 1
						WHEN pl.BetFrom IS NOT NULL THEN 1
						WHEN apl.BetFrom IS NULL AND ',' + @BetFrom + ',' LIKE '%,88,%' THEN 1
						WHEN apl.BetFrom IS NULL AND ',' + @BetFrom + ',' LIKE '%,99,%' THEN 1
						ELSE 0
					END

		-- translog
		IF @BetType IN ('', 'Others')
		BEGIN
			INSERT INTO @Data (
				CustId,
				MatchId,
				SportType,
				BetType,
				TransId,
				RefNo,
				TransDate,
				BetId,
				LiveHomeScore,
				LiveAwayScore,
				LiveIndicator,
				Hdp1,
				Hdp2,
				Odds,
				Actual_Stake,
				Stake,
				BetFrom,
				Status,
				BetTeam,
				OddsType,
				Ip,
				CurrencyId,
				SpecialLevel,
				BetCheck,
				TransDesc,
				BetdaqId,
				ExtraInfo,
				OriginalStake,
				OriginalBetType,
				WalletType,
				RefCode,
				OddsSpread)
			SELECT
				b.custid,
				0 AS MatchId,
				b.productID AS SportType,
				b.gameID AS BetType,
				b.translogid AS TransId,
				b.translogid AS RefNo,
				b.transdate,
				0 AS BetId,
				0 AS LiveHomeScore,
				0 AS LiveAwayScore,
				0 AS LiveIndicator,
				0 AS Hdp1,
				0 AS Hdp2,
				b.odds,
				b.actual_stake,
				b.stake,
				b.betfrom,
				b.status,
				'' AS BetTeam,
				0 AS OddsType,
				b.ip,
				b.currency AS CurrencyId,
				0 AS SpecialLevel,
				ISNULL(b.TranId3rd, '') AS BetCheck,
				ISNULL(b.transdesc, '') AS TransDesc,
				-1 AS BetdaqId,
				'' AS ExtraInfo,
				0 AS OriginalStake,
				0 AS OriginalBetType,
				0 AS WalletType,
				0 AS RefCode,
				0 AS OddsSpread
			FROM dbo.translog AS b WITH (NOLOCK)
				INNER JOIN #TempAg AS a ON b.Recommend = a.CustId
				LEFT JOIN #PlatformList AS pl ON pl.BetFrom = b.betfrom
				LEFT JOIN #AllPlatformList AS apl ON apl.BetFrom = b.betfrom
			WHERE b.statusID IN (0, 1)
				AND b.translogid > @TransLogId
				AND (@Currency = ''
					OR ',' + @Currency + ',' LIKE '%,' + CONVERT(VARCHAR(3), b.currency) + ',%')
				AND (@LiveIndicator = 3
					OR (@LiveIndicator IN (0, 1) AND b.LiveIndicator = @LiveIndicator))
				AND 1 = CASE
						WHEN @BetFrom = 'All' THEN 1
						WHEN pl.BetFrom IS NOT NULL THEN 1
						WHEN apl.BetFrom IS NULL AND ',' + @BetFrom + ',' LIKE '%,88,%' THEN 1
						WHEN apl.BetFrom IS NULL AND ',' + @BetFrom + ',' LIKE '%,99,%' THEN 1
						ELSE 0
					END
		END

		IF EXISTS (SELECT TOP(1) 1 FROM @Data)
		BEGIN
			-- Get sport/bettype matrix
			DECLARE @SportBettype TABLE(ProductID TINYINT, BetType SMALLINT, EventType TINYINT, RefTable TINYINT)

			DECLARE @IsTest BIT = 0

			SELECT @IsTest = dbo.f_CheckSPVersion(@@PROCID)

			INSERT INTO @SportBettype
			SELECT DISTINCT
				ma.ProductID,
				ma.BetType,
				ma.EventType,
				ma.RefTable
			FROM dbo.SportBettypeMatrix AS ma WITH (NOLOCK)
				INNER JOIN dbo.Products AS p WITH (NOLOCK) ON p.ProductID = ma.ProductID
				LEFT JOIN #TempSportType AS ts
					ON (ts.SportType = ma.SportType AND ma.BetType NOT IN (9, 29))
					OR (ts.SportType = 999 AND ma.BetType IN (9, 29))
			WHERE (@SportTypeList = 'All' OR ts.SportType IS NOT NULL)
				AND ',' + @ProductList + ',' LIKE '%,' + p.ProductPrefix + ',%'
				AND (ma.IsTest = 0 OR ma.IsTest = @IsTest)

			-- Delete unselected products
			UPDATE b
			SET ProductId = s.ProductID,
				EventType = s.EventType
			FROM @Data AS b
				INNER JOIN @SportBettype AS s ON b.bettype = s.BetType

			DELETE @Data WHERE ProductId IS NULL

			-- Get event info
			UPDATE b
			SET SportType = m.sporttype,
				LeagueId = m.leagueid,
				LeagueGroupId = l.LeagueGroupID
			FROM @Data AS b
				INNER JOIN dbo.match AS m WITH (NOLOCK) ON m.matchid = b.MatchId
				INNER JOIN dbo.League AS l WITH (NOLOCK) ON l.leagueid = m.leagueid
			WHERE b.ProductId = 1 AND b.EventType = 1

			UPDATE b
			SET SportType = l.sporttype,
				LeagueId = l.leagueid,
				LeagueGroupId = l.LeagueGroupID
			FROM @Data AS b
				INNER JOIN dbo.outright AS o WITH (NOLOCK) ON o.orid = b.MatchId
				INNER JOIN dbo.League AS l WITH (NOLOCK) ON l.leagueid = o.leagueid
			WHERE b.ProductId = 1 AND b.EventType = 2

			-- Delete unselected matches
			IF @MatchId <> 0
			BEGIN
				DELETE FROM @Data
				WHERE ProductId = 1
					AND EventType = 1
					AND MatchId <> @MatchId
			END

			-- Delete unselected leagues
			IF @LeagueList <> 'All'
			BEGIN
				DELETE FROM @Data
				WHERE ProductId = 1
					AND EventType IN (1, 2)
					AND ',' + @LeagueList + ',' NOT LIKE '%,' + CONVERT(VARCHAR(11), LeagueId) + ',%'
			END

			-- Delete unselected sport types
			IF @SportTypeList <> 'All'
			BEGIN
				-- Normal sport types
				DELETE b
				FROM @Data AS b
				WHERE b.ProductId = 1
					AND b.EventType IN (1, 2)
					AND NOT EXISTS (SELECT 1 FROM @FullSportType WHERE SportType = b.SportType)
					AND NOT EXISTS (SELECT 1 FROM #TempSportType WHERE SportType = b.SportType)

				-- Special league group
				DELETE b
				FROM @Data AS b
				WHERE b.ProductId = 1
					AND b.EventType IN (1, 2)
					AND EXISTS (SELECT 1 FROM @FullSportType
								WHERE SportType = b.SportType
									AND ',' + LeagueGroupIdList + ',' LIKE '%,' + CONVERT(VARCHAR(6), b.LeagueGroupId) + ',%')
					AND NOT EXISTS (SELECT 1 FROM #TempSportType
									WHERE SportType = b.SportType
										AND ',' + LeagueGroupIdList + ',' LIKE '%,' + CONVERT(VARCHAR(11), b.LeagueGroupId) + ',%')

				-- Normal league group
				DELETE b
				FROM @Data AS b
				WHERE b.ProductId = 1
					AND b.EventType IN (1, 2)
					AND NOT EXISTS (SELECT 1 FROM @FullSportType
									WHERE SportType = b.SportType
										AND ',' + LeagueGroupIdList + ',' LIKE '%,' + CONVERT(VARCHAR(6), b.LeagueGroupId) + ',%')
					AND NOT EXISTS (SELECT 1 FROM #TempSportType
									WHERE SportType = b.SportType AND LeagueGroupIdList = '0')
			END

			-- Delete unselected special level
			UPDATE b
			SET b.SpecialLevel = ISNULL(d.SpecialLevel, 0)
			FROM @Data AS b
				INNER JOIN dbo.Dep_CustSpecialLevel AS d WITH (NOLOCK) ON b.custid = d.custid

			IF @SpecialLevel <> ''
			BEGIN
				DELETE @Data
				WHERE ',' + @SpecialLevel + ',' NOT LIKE '%,' + CONVERT(VARCHAR(3), SpecialLevel) + ',%'
			END

			-- Delete unselected customer class
			UPDATE b
			SET b.CustomerClass = ISNULL(c.CustomerClass, 0)
			FROM @Data AS b
				INNER JOIN dbo.custInfo AS c WITH (NOLOCK) ON c.custid = b.custid

			IF @CustomerClass <> 'All'
			BEGIN
				DELETE @Data
				WHERE 1 <> CASE
								WHEN ',' + @CustomerClass + ',' LIKE '%,0,%' AND CustomerClass IS NULL THEN 1
								WHEN ',' + @CustomerClass + ',' LIKE '%,0,%'
									AND ',' + @FullCustomerClass + ',' NOT LIKE '%,' + CONVERT(VARCHAR(6), CustomerClass) + ',%' THEN 1
								WHEN ',' + @CustomerClass + ',' LIKE '%,' + CONVERT(VARCHAR(6), CustomerClass) + ',%' THEN 1
								ELSE 0
							END
			END
		END

		-- Get data for summary ticket of multiple Bonus/Cash sub tickets
		IF EXISTS (SELECT 1 FROM @Data WHERE RefCode <> 0)
		BEGIN
			DECLARE @RefCodeTmp TABLE (
				RefCode			BIGINT,
				TransId			BIGINT,
				Stake			MONEY,
				Actual_Stake	MONEY
			)

			-- Prepare temp table
			INSERT INTO @RefCodeTmp
			SELECT
				RefCode,
				MIN(TransId) AS TransId,
				SUM(Stake) AS Stake,
				SUM(Actual_Stake) AS Actual_Stake
			FROM @Data
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
					b.WalletType = 0
				FROM @Data AS b
					INNER JOIN @RefCodeTmp AS r ON b.RefCode = r.RefCode AND b.TransId = r.TransId

				-- Delete 2nd Bonus/Cash tickets
				DELETE @Data
				WHERE WalletType <> 0
					AND RefCode IN (SELECT RefCode FROM @RefCodeTmp)
			END
		END

		-- Display detail link for ticket from Bonus Wallet only
		UPDATE @Data
		SET RefCode = TransId
		WHERE WalletType = 1 AND RefCode = 0

		-- Don't display Cash text for ticket from Cash Wallet only
		UPDATE @Data
		SET WalletType = 0
		WHERE WalletType = 2 AND RefCode = 0

		-- Get exchange rate
		IF @BaseCurrency <> ''
		BEGIN
			INSERT INTO @ExchangeRate
			SELECT
				e.ExchangeId,
				e.Rate
			FROM dbo.Lrf_f_GetExchangeRate(CONVERT(VARCHAR(10), GETDATE(), 111), CONVERT(VARCHAR(10), GETDATE(), 111), @BaseCurrency, '') AS e
		END
	END

	SELECT
		c.username,
		SUBSTRING(c.username2, CHARINDEX('$', c.username2) + 1, LEN(c.username2) - CHARINDEX('$', c.username2)) AS Nickname,
		b.CustId,
		b.CustomerClass,
		b.MatchId,
		b.SportType,
		b.BetType,
		b.TransId,
		b.RefNo,
		b.TransDate,
		b.BetId,
		b.LiveHomeScore,
		b.LiveAwayScore,
		b.LiveIndicator,
		b.Hdp1,
		b.Hdp2,
		b.Odds,
		CAST(b.Actual_Stake * ISNULL(b.Rate, 1) AS DECIMAL(19, 8)) AS Actual_Stake,
		CAST(b.Stake * ISNULL(b.Rate, 1) AS DECIMAL(19, 8)) AS Stake,
		b.BetFrom,
		b.Status,
		b.BetTeam,
		b.OddsType,
		b.Ip,
		b.CurrencyId AS Currency,
		b.SpecialLevel,
		b.BetCheck,
		b.TransDesc,
		b.BetdaqId,
		b.ExtraInfo,
		CAST(b.OriginalStake * ISNULL(b.Rate, 1) AS DECIMAL(19, 8)) AS OriginalStake,
		b.OriginalBetType,
		b.WalletType,
		b.RefCode,
		b.OddsSpread
	FROM
		(
			SELECT TOP(@LimitRowCount)
				d.*,
				e.Rate
			FROM @Data AS d
				LEFT JOIN @ExchangeRate AS e ON e.exchangeid = d.CurrencyId
			WHERE (@MinStake = 0 OR d.Stake * ISNULL(e.Rate, 1) >= @MinStake)
				AND (@MaxStake = 0 OR d.Stake * ISNULL(e.Rate, 1) <= @MaxStake)
			ORDER BY d.TransDate DESC
		) AS b
		LEFT JOIN dbo.Customer AS c WITH (NOLOCK) ON b.CustId = c.custid
	ORDER BY b.TransDate DESC

	DROP TABLE #PlatformList
END
GO
