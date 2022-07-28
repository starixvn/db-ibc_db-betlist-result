/*<info serverAlias="DBSID-bodb02" executers="bodbLicenseeNet" viewers="" isFunction="0" isNested="0"></info>*/

ALTER PROCEDURE [dbo].[SiteDB_Lrf_BetList_LastBetsMonitoring]
	@AgentList		VARCHAR(MAX),
	@ProductList	VARCHAR(100)	= '',
	@BetType		VARCHAR(50)		= '',
	@Currency		VARCHAR(200)	= '',
	@SpecialLevel	VARCHAR(200)	= '',
	@TransId		BIGINT			= 0,
	@TransLogId		BIGINT			= 0,
	@LimitRowCount	INT				= 10,
	@SportTypeList	VARCHAR(MAX)	= 'All',
	@LeagueList		VARCHAR(MAX)	= 'All',
	@MatchId		INT				= 0,
	@MinStake		MONEY			= 0,
	@MaxStake		MONEY			= 0,
	@LiveIndicator	INT				= 0,
	@BetFrom		VARCHAR(100)	= 'All',
	@CustomerClass	VARCHAR(200)	= 'All',
	@BaseCurrency	VARCHAR(10)		='USD',
	@Debug			BIT				= 0
AS

/*
	Created: 20220727@Kos
	Task: LAP - Last Bets Monitoring - SiteDB
	DB: DBSID.bodb02

	Revision:
		- 20220727@Kos: Created [Redmine: #175297]

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
		BetFrom			NVARCHAR(1),
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

		CREATE TABLE #PlatformList (PlatformType TINYINT, BetFrom NVARCHAR(1) PRIMARY KEY)

		INSERT INTO #PlatformList (PlatformType, BetFrom)
		SELECT PlatformType, betfrom
		FROM dbo.Lrf_f_BetFromType_Sel(@BetFrom)

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
		FROM dbo.bettrans AS b WITH (NOLOCK)
			INNER JOIN #TempAg AS a ON b.Recommend = a.CustId
			INNER JOIN #PlatformList AS pl ON pl.BetFrom = b.betfrom
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
				ISNULL(b.GameId3rd, '') AS BetCheck,
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
				INNER JOIN #PlatformList AS pl ON pl.BetFrom = b.betfrom
			WHERE b.statusID IN (0, 1)
				AND b.translogid > @TransLogId
				AND (@Currency = ''
					OR ',' + @Currency + ',' LIKE '%,' + CONVERT(VARCHAR(3), b.currency) + ',%')
				AND (@LiveIndicator = 3
					OR (@LiveIndicator IN (0, 1) AND b.LiveIndicator = @LiveIndicator))
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
				INNER JOIN DBCUST.CustDB.dbo.Dep_CustSpecialLevel AS d WITH (NOLOCK) ON b.custid = d.custid

			IF @SpecialLevel <> ''
			BEGIN
				DELETE @Data
				WHERE ',' + @SpecialLevel + ',' NOT LIKE '%,' + CONVERT(VARCHAR(3), SpecialLevel) + ',%'
			END

			-- Delete unselected customer class
			UPDATE b
			SET b.CustomerClass = ISNULL(c.CustomerClass, 0)
			FROM @Data AS b
				INNER JOIN CustDB.dbo.custInfo AS c WITH (NOLOCK) ON c.custid = b.custid

			IF @CustomerClass <> 'All'
			BEGIN
				DELETE @Data
				WHERE ',' + @CustomerClass + ',' NOT LIKE '%,' + CONVERT(VARCHAR(6), CustomerClass) + ',%'
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
			FROM dbo.SiteDB_Lrf_f_GetExchangeRate(CONVERT(VARCHAR(10), GETDATE(), 111), CONVERT(VARCHAR(10), GETDATE(), 111), @BaseCurrency, '') AS e
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
		b.Actual_Stake * ISNULL(b.Rate, 1) AS Actual_Stake,
		b.Stake * ISNULL(b.Rate, 1) AS Stake,
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
		b.OriginalStake * ISNULL(b.Rate, 1) AS OriginalStake,
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
		LEFT JOIN CustDB.dbo.Customer AS c WITH (NOLOCK) ON b.CustId = c.custid
	ORDER BY b.TransDate DESC

	DROP TABLE #PlatformList
END
GO
