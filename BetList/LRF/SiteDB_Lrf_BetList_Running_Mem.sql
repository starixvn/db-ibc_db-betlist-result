/*<info serverAlias="DBSID-bodb02" executers="wsv_lap" viewers="" isFunction="0" isNested="0"></info>*/

ALTER PROCEDURE [dbo].[SiteDB_Lrf_BetList_Running_Mem]
	@AgentList	VARCHAR(MAX),
	@CustId		INT,
	@PageSize	INT		= 1000,
	@PageIndex	INT		= 1,
	@SortType	TINYINT	= 0,		-- TransDate
	@SortOrder	TINYINT	= 1,		-- ASC
	@TotalRows	INT		= 0 OUTPUT,
	@SumStake	MONEY	= 0 OUTPUT
AS

/*
	Created: 20220727@Kos
	Task: Player Admin - Running Bet List - SiteDB
	DB: DBSID.bodb02
	Param's Explanation:
		- @SortType:
			- 0: TransDate
			- 1: Stake
		- @SortOrder
			- 1: ASC
			- 2: DESC

	Revisions:
		- 20220727@Kos: Created [Redmine: #175297]
		- 20230119@Kos: Support Jili [Redmine: 182914]
		- 20230328@Kos: Remove inactive products FW, GDG, CB [Redmine: 181424]
		- 20230404@Kos: Extend betfrom length [Redmine: #178059]
		- 20230602@Kos: Support YeeBet [Redmine: 187947]
		- 20230629@Kos: Support MG-RNG [Redmine: 189988]
		- 20230803@Kos: Support Virtual Sports 3 [Redmine: 190908]
		- 20231107@Kos: Support SEAL Entertaiment [Redmine: 180648]
		- 20231110@Kos: Support WE Live Casino [Redmine: 196573]
		- 20231227@Kos: Hotfix - cannot view result [Redmine: 198900]
		- 20240102@Kos: Extend data type [Redmine: 198966]
		- 20240412@Kos: Support Gaming API [Redmine: 203734]
		- 20240425@Kos: Return LeagueGroupId to support Jollysports [Redmine: #203258]
		- 20240605@Kos: Support Virtual Sports 4 [Redmine: 199347]
		- 20240919@Kos: Support BetRadar Horse Racing [Redmine: #210808]
		- 20241028@Kos: Support Virtual Sports 6 [Redmine: 212446]
		- 20241216@Kos: Support Virtual Sports 5 [Redmine: 207582]
		- 20250702@Kos: Fix security issue in dynamic query [#Redmine: 227496]
					- Remove input param @Sort
					- Add new input params @SortType TINYINT, @SortOrder TINYINT
		- 20251028@Kelvin: Integrate - Jacktime - Basketball Main Bettype Hybrid Parlay [#Redmine: 242357]
*/

BEGIN
	SET NOCOUNT ON

	DECLARE @HasError BIT = 0

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
		SET @HasError = 1
	END CATCH

	CREATE TABLE #Data (
		TransId				BIGINT,
		RefNo				BIGINT,
		CustId				INT,
		Currency			SMALLINT,
		Recommend			INT,
		SportType			SMALLINT,
		BetType				SMALLINT,
		BetId				BIGINT,
		BetTeam				NVARCHAR(20),
		Hdp1				SMALLMONEY,
		Hdp2				SMALLMONEY,
		OddsId				INT,
		OddsType			TINYINT,
		Odds				MONEY,
		MOdds				MONEY,
		OddsSpread			MONEY,
		Stake				MONEY,
		Actual_Stake		MONEY,
		Status				NVARCHAR(10),
		SettlementStatus	TINYINT,
		SecAcceptFlag		BIT,
		CheckTime			DATETIME,
		TransDate			DATETIME,
		WinLostDate			SMALLDATETIME,
		LiveIndicator		BIT,
		LiveHomeScore		SMALLINT,
		LiveAwayScore		SMALLINT,
		Ip					VARCHAR(45),
		BetFrom				NVARCHAR(4),
		LeagueId			INT,
		LeagueGroupId		SMALLINT,
		MatchId				INT,
		MatchCode			NVARCHAR(50),
		Race				NVARCHAR(50),
		EventDate			DATETIME,
		HomeId				INT,
		AwayId				INT,
		BetStatus			NVARCHAR(50),
		IsNeutral			BIT,
		Placing				NVARCHAR(20),
		ShowTime			NVARCHAR(50),
		BetCheck			NVARCHAR(50),
		ComStatus			NVARCHAR(20),
		TransDesc			NVARCHAR(1000),
		BetdaqId			BIGINT,
		ExtraInfo			VARCHAR(1000),
		OriginalStake		MONEY,
		OriginalBetType		SMALLINT,
		WalletType			TINYINT,
		RefCode				BIGINT,
		ProductId			INT,
		Custom1				NVARCHAR(50),
		Custom2				NVARCHAR(50),
		Custom3				NVARCHAR(50),
		Gameid3rd			NVARCHAR(50),
		Tranid3rd			NVARCHAR(200),
		TableID				TINYINT,
		Product				VARCHAR(30),
		RefTable			TINYINT,
		EventType			TINYINT
	)

	CREATE TABLE #PagingData (
		RowNum				INT,
		TransId				BIGINT,
		RefNo				BIGINT,
		CustId				INT,
		Currency			SMALLINT,
		Recommend			INT,
		SportType			SMALLINT,
		BetType				SMALLINT,
		BetId				BIGINT,
		BetTeam				NVARCHAR(20),
		Hdp1				SMALLMONEY,
		Hdp2				SMALLMONEY,
		OddsId				INT,
		OddsType			TINYINT,
		Odds				MONEY,
		MOdds				MONEY,
		OddsSpread			MONEY,
		Stake				MONEY,
		Actual_Stake		MONEY,
		Status				NVARCHAR(10),
		SettlementStatus	TINYINT,
		SecAcceptFlag		BIT,
		CheckTime			DATETIME,
		TransDate			DATETIME,
		WinLostDate			SMALLDATETIME,
		LiveIndicator		BIT,
		LiveHomeScore		SMALLINT,
		LiveAwayScore		SMALLINT,
		Ip					VARCHAR(45),
		BetFrom				NVARCHAR(4),
		LeagueId			INT,
		LeagueGroupId		SMALLINT,
		MatchId				INT,
		MatchCode			NVARCHAR(50),
		Race				NVARCHAR(50),
		EventDate			DATETIME,
		HomeId				INT,
		AwayId				INT,
		BetStatus			NVARCHAR(50),
		IsNeutral			BIT,
		Placing				NVARCHAR(20),
		ShowTime			NVARCHAR(50),
		BetCheck			NVARCHAR(50),
		ComStatus			NVARCHAR(20),
		TransDesc			NVARCHAR(1000),
		BetdaqId			BIGINT,
		ExtraInfo			VARCHAR(1000),
		OriginalStake		MONEY,
		OriginalBetType		SMALLINT,
		WalletType			TINYINT,
		RefCode				BIGINT,
		ProductId			INT,
		Custom1				NVARCHAR(50),
		Custom2				NVARCHAR(50),
		Custom3				NVARCHAR(50),
		Gameid3rd			NVARCHAR(50),
		Tranid3rd			NVARCHAR(200),
		TableID				TINYINT,
		Product				VARCHAR(30),
		RefTable			TINYINT,
		EventType			TINYINT
	)

	DECLARE @TmpData TABLE (
		RefNo			BIGINT,
		BetType			SMALLINT,
		Stake			MONEY,
		Actual_Stake	MONEY,
		IsNew			BIT
	)

	DECLARE @Detail TABLE (
		RefNo		BIGINT,
		Odds		MONEY,
		Stake		MONEY,
		Status		NVARCHAR(10),
		BetType		SMALLINT,
		BetTeam		NVARCHAR(10)
	)

	IF @HasError = 0
	BEGIN
		-- bettrans
		INSERT INTO #Data (
			TransId, RefNo, CustId, Currency, Recommend, BetType, BetId, BetTeam, Hdp1, Hdp2,
			OddsId, OddsType, Odds, MOdds, OddsSpread, Stake, Actual_Stake, Status, SecAcceptFlag, CheckTime,
			TransDate, WinLostDate, LiveIndicator, LiveHomeScore, LiveAwayScore, Ip, BetFrom, MatchId, BetCheck, ComStatus,
			TransDesc, BetdaqId, ExtraInfo, WalletType, RefCode, TableID
		)
		SELECT
			b.transid,
			b.refno,
			b.custid,
			b.currency,
			b.recommend,
			b.bettype,
			ISNULL(b.betid, 0) AS BetId,
			b.betteam,
			b.hdp1,
			b.hdp2,
			b.oddsid,
			b.oddstype,
			b.odds,
			b.modds,
			b.oddsspread,
			b.stake,
			b.actual_stake,
			b.status,
			b.SecAcceptFlag,
			b.checktime,
			b.transdate,
			b.winlostdate,
			b.liveindicator,
			b.livehomescore,
			b.liveawayscore,
			b.ip,
			b.betfrom,
			b.matchid,
			b.betcheck,
			b.comstatus,
			b.transdesc,
			b.betdaqid,
			b.ExtraInfo,
			b.WalletType,
			ISNULL(b.RefCode, 0),
			1 AS TableID
		FROM dbo.bettrans AS b WITH (NOLOCK)
		WHERE b.custid = @CustId AND b.statusID IN (0, 1)

		-- translog
		INSERT INTO #Data (
			TransId, RefNo, CustId, Currency, Recommend, BetType, Odds, Stake, Actual_Stake, Status,
			TransDate, WinLostDate, LiveIndicator, Ip, BetFrom, TransDesc, ProductId, Custom1, Custom2, Custom3,
			Gameid3rd, Tranid3rd, TableID
		)
		SELECT
			tl.translogid AS TransId,
			tl.translogid AS RefNo,
			tl.custid,
			tl.currency,
			tl.recommend,
			tl.gameID AS BetType,
			tl.odds,
			tl.stake,
			tl.actual_stake,
			tl.status,
			tl.transdate,
			tl.transdate AS WinLostDate,
			tl.LiveIndicator,
			tl.ip,
			tl.betfrom,
			tl.transdesc,
			tl.productID,
			tl.custom1,
			tl.custom2,
			tl.custom3,
			tl.GameId3rd,
			tl.TranId3rd,
			2 AS TableID
		FROM dbo.translog AS tl WITH (NOLOCK)
		WHERE tl.custid = @CustId AND tl.statusID IN (0, 1)

		DELETE b
		FROM #Data AS b
		WHERE NOT EXISTS (SELECT 1 FROM @TempAg WHERE CustId = b.Recommend AND Currency = b.Currency)

		DECLARE @IsTest BIT = 0

		SELECT @IsTest = dbo.f_CheckSPVersion(@@PROCID)

		-- Get Sport/Bettype info
		UPDATE b
		SET
			Product = CASE
						WHEN s.ProductID = 6 THEN 'OneRNG'							-- RNG Casino
						WHEN s.ProductID = 8 THEN 'Keno'
						WHEN s.ProductID = 11 THEN 'AG'								-- AG Casino
						WHEN s.ProductID = 21 THEN 'AllBet'
						WHEN s.ProductID = 22 THEN 'VB'								-- Macau Games
						WHEN s.ProductID = 28 THEN 'Lottery'
						WHEN s.ProductID = 32 THEN 'PP'								-- Pragmatic Play Casino
						WHEN s.ProductID = 34 THEN 'CC'								-- Card Club
						WHEN s.ProductID = 36 THEN 'SG'								-- Spadegaming
						WHEN s.ProductID = 38 THEN 'VRG'							-- Virtual Games
						WHEN s.ProductID = 39 THEN 'SAG'							-- SA Gaming
						WHEN s.ProductID = 40 THEN 'TG'								-- Table Games
						WHEN s.ProductID = 42 THEN 'SBC'							-- Saba.club
						WHEN s.ProductID = 43 THEN 'I4D'							-- Indo 4D
						WHEN s.ProductID = 45 THEN 'SXG'							-- Sexy Gaming
						WHEN s.ProductID = 49 THEN 'VS3'							-- Virtual Sports 3 (Old)
						WHEN s.ProductID = 51 THEN 'WM'								-- WM Live Casino
						WHEN s.ProductID = 55 THEN 'PGS'							-- PG Soft
						WHEN s.ProductID = 56 THEN 'JK'								-- Joker
						WHEN s.ProductID = 57 THEN 'BG'								-- Big Gaming
						WHEN s.ProductID = 60 THEN 'MXG'							-- MaxGame
						WHEN s.ProductID = 61 THEN 'HB'								-- Habanero
						WHEN s.ProductID = 62 THEN 'CG'								-- CG
						WHEN s.ProductID = 63 THEN 'SLT'							-- Sports Lottery
						WHEN s.ProductID = 66 THEN 'VGA'							-- Vgaming
						WHEN s.ProductID = 67 THEN 'AP'								-- AdvantPlay
						WHEN s.ProductID = 68 THEN 'APM'							-- AdvantPlay Mini
						WHEN s.ProductID = 69 THEN 'BTC'							-- Bitcoin
						WHEN s.ProductID = 70 THEN 'FGGL'							-- FGG
						WHEN s.ProductId = 72 THEN 'SEA'							-- SEAL Entertainment
						WHEN s.ProductID = 73 THEN 'MGRNG'							-- MG-RNG
						WHEN s.ProductID = 75 THEN 'JIG'							-- Jili
						WHEN s.ProductID = 76 THEN 'YB'								-- YeeBet
						WHEN s.ProductID = 77 THEN 'LG'								-- Virtual Sports 3
						WHEN s.EventType = 0 AND s.ProductID = 1 THEN 'Parlay'		-- Sportsbook Parlay
						WHEN s.EventType = 0 AND s.ProductID = 3 THEN 'H5LG'		-- Happy 5 Linked Games (Number Game)
						WHEN s.EventType = 0 AND s.ProductID = 27 THEN 'ParlayVS2'	-- Betradar Virtual Sports Parlay
						WHEN s.EventType = 1 AND s.ProductID = 1 THEN 'SB'			-- Sportsbook
						WHEN s.EventType = 1 AND s.ProductID = 3 THEN 'NG'			-- Number Game
						WHEN s.EventType = 1 AND s.ProductID = 5 THEN 'VS'			-- Virtual Sports Sportsbook
						WHEN s.EventType = 1 AND s.ProductID = 27 THEN 'VS2'		-- Betradar Virtual Sports
						WHEN s.EventType = 2 AND s.ProductID = 1 THEN 'Outright'
						ELSE 'Unknown'
					END,
			RefTable = s.RefTable,
			EventType = s.EventType
		FROM #Data AS b
			INNER JOIN dbo.f_SportBettypeMatrix_Sel (0, 0, 0, 2, '', '', @IsTest) AS s ON b.bettype = s.bettype

		DELETE #Data
		WHERE Product IS NULL

		DECLARE @Yesterday SMALLDATETIME = DATEADD(DAY, DATEDIFF(DAY, 1, CURRENT_TIMESTAMP), 0)

		-- bettransRnG
		INSERT INTO @TmpData
		(
			RefNo,
			BetType,
			Stake,
			Actual_Stake,
			IsNew
		)
		SELECT
			rng.RefNo,
			rng.gameID AS BetType,
			SUM(rng.stake) AS Stake,
			SUM(rng.actual_stake) AS Actual_Stake,
			1 AS IsNew
		FROM dbo.bettransRnG AS rng WITH (NOLOCK)
			INNER JOIN dbo.f_SportBettypeMatrix_Sel (0, 0, 0, 2, '', '', @IsTest) AS s ON rng.gameID = s.bettype
		WHERE rng.custid = @CustId
			AND rng.winlostdate >= @Yesterday
			AND rng.statusID IN (0, 1)
			AND s.RefTable = 1
		GROUP BY rng.RefNo,
			rng.gameID

		---- bettransLC
		INSERT INTO @TmpData
		(
			RefNo,
			BetType,
			Stake,
			Actual_Stake,
			IsNew
		)
		SELECT
			lc.RefNo,
			lc.gameID AS BetType,
			SUM(lc.stake) AS Stake,
			SUM(lc.actual_stake) AS Actual_Stake,
			1 AS IsNew
		FROM dbo.bettransLC AS lc WITH (NOLOCK)
			INNER JOIN dbo.f_SportBettypeMatrix_Sel (0, 0, 0, 2, '', '', @IsTest) AS s ON lc.gameID = s.bettype
		WHERE lc.custid = @CustId
			AND lc.winlostdate >= @Yesterday
			AND lc.statusID IN (0, 1)
			AND s.RefTable = 2
		GROUP BY lc.RefNo,
			lc.gameID

		-- Delete settled only summary ticket
		DELETE b
		FROM #Data AS b
		WHERE b.RefTable IN (1, 2)
			AND b.Winlostdate >= @Yesterday
			AND NOT EXISTS (SELECT 1 FROM @TmpData WHERE RefNo = b.TransId)

		-- Update tickets EXISTS in #Data
		UPDATE b
		SET b.IsNew = 0
		FROM @TmpData AS b
			INNER JOIN #Data AS d ON d.TransId = b.RefNo AND d.BetType = b.BetType
		WHERE d.Winlostdate >= @Yesterday AND d.RefTable IN (1, 2)

		INSERT INTO #Data (
			TransId, RefNo, CustId, Currency, Recommend, BetType, BetId, BetTeam, Hdp1, Hdp2,
			OddsId, OddsType, Odds, MOdds, OddsSpread, Stake, Actual_Stake, Status, SecAcceptFlag, CheckTime,
			TransDate, WinLostDate, LiveIndicator, LiveHomeScore, LiveAwayScore, Ip, BetFrom, MatchId, BetCheck, ComStatus,
			TransDesc, BetdaqId, ExtraInfo, WalletType, RefCode, TableID, Product, RefTable, EventType
		)
		SELECT
			bt.transid,
			bt.refno,
			bt.custid,
			bt.currency,
			bt.recommend,
			bt.bettype,
			ISNULL(bt.betid, 0) AS BetId,
			bt.betteam,
			bt.hdp1,
			bt.hdp2,
			bt.oddsid,
			bt.oddstype,
			bt.odds,
			bt.modds,
			bt.oddsspread,
			bt.stake,
			bt.actual_stake,
			bt.status,
			bt.SecAcceptFlag,
			bt.checktime,
			bt.transdate,
			bt.winlostdate,
			bt.liveindicator,
			bt.livehomescore,
			bt.liveawayscore,
			bt.ip,
			bt.betfrom,
			bt.matchid,
			bt.betcheck,
			bt.comstatus,
			bt.transdesc,
			bt.betdaqid,
			bt.ExtraInfo,
			bt.WalletType,
			ISNULL(bt.RefCode, 0),
			1 AS TableID,
			CASE
				WHEN s.ProductID = 6 THEN 'OneRNG'	-- RNG Casino
				WHEN s.ProductID = 11 THEN 'AG'		-- AG Casino
				WHEN s.ProductID = 21 THEN 'AllBet'
				WHEN s.ProductID = 22 THEN 'VB'		-- Macau Games
				WHEN s.ProductID = 32 THEN 'PP'		-- Pragmatic Play Casino
				WHEN s.ProductID = 34 THEN 'CC'		-- Card Club
				WHEN s.ProductID = 36 THEN 'SG'		-- Spadegaming
				WHEN s.ProductID = 39 THEN 'SAG'	-- SA Gaming
				WHEN s.ProductID = 42 THEN 'SBC'	-- Saba.club
				WHEN s.ProductID = 45 THEN 'SXG'	-- Sexy Gaming
				WHEN s.ProductID = 51 THEN 'WM'		-- WM Live Casino
				WHEN s.ProductID = 55 THEN 'PGS'	-- PG Soft
				WHEN s.ProductID = 56 THEN 'JK'		-- Joker
				WHEN s.ProductID = 57 THEN 'BG'		-- Big Gaming
				WHEN s.ProductID = 60 THEN 'MXG'	-- MaxGame
				WHEN s.ProductID = 61 THEN 'HB'		-- Habanero
				WHEN s.ProductID = 62 THEN 'CG'		-- CG
				WHEN s.ProductID = 66 THEN 'VGA'	-- Vgaming
				WHEN s.ProductID = 67 THEN 'AP'		-- AdvantPlay
				WHEN s.ProductID = 68 THEN 'APM'	-- AdvantPlay Mini
				WHEN s.ProductID = 70 THEN 'FGGL'	-- FGG
				WHEN s.ProductId = 72 THEN 'SEA'	-- SEAL Entertainment
				WHEN s.ProductID = 73 THEN 'MGRNG'	-- MG-RNG
				WHEN s.ProductID = 75 THEN 'JIG'	-- Jili
				WHEN s.ProductID = 76 THEN 'YB'		-- YeeBet
				ELSE 'Unknown'
			END AS Product,
			s.RefTable,
			s.EventType
		FROM dbo.bettrans AS bt WITH (NOLOCK)
			INNER JOIN @TmpData AS t ON t.RefNo = bt.transid AND t.BetType = bt.BetType
			INNER JOIN dbo.f_SportBettypeMatrix_Sel (0, 0, 0, 2, '', '', @IsTest) AS s ON bt.bettype = s.bettype
		WHERE bt.custid = @CustId
			AND t.IsNew = 1

		IF EXISTS (SELECT TOP(1) 1 FROM #Data)
		BEGIN
			-- Get data for summary ticket of multiple Bonus/Cash sub tickets
			IF EXISTS (SELECT 1 FROM #Data WHERE RefCode <> 0)
			BEGIN
				DECLARE @RefCodeTmp TABLE (
					RefCode	BIGINT,
					TransId	BIGINT,
					Stake	MONEY
				)

				-- Prepare temp table
				INSERT INTO @RefCodeTmp (RefCode, TransId, Stake)
				SELECT
					RefCode,
					MIN(TransId) AS TransId,
					SUM(Stake) AS Stake
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

			-- Return data
			SELECT
				@TotalRows = COUNT(1),
				@SumStake = SUM(b.Stake)
			FROM #Data AS b

			-- Get sort text
			DECLARE @SortText VARCHAR(100)

			-- Get sort text
			SET @SortText = CASE
								WHEN @SortType = 0 THEN 'TransDate'
								WHEN @SortType = 1 THEN 'Stake'
								ELSE ''
							END

			SET @SortText = @SortText + ' ' + CASE
												WHEN @SortOrder = 1 THEN 'ASC'
												WHEN @SortOrder = 2 THEN 'DESC'
												ELSE ''
											END

			DECLARE @RowStart INT,
				@RowEnd INT

			SELECT @PageIndex = @PageIndex - 1,
				@RowStart = @PageSize * @PageIndex + 1,
				@RowEnd = @RowStart + @PageSize - 1

			DECLARE @Sql NVARCHAR(2000)

			SET @Sql = 
				N'SELECT a.*
				FROM
					(
						SELECT
							ROW_NUMBER() OVER (ORDER BY ' + @SortText + N') AS RowNum,
							d.*
						FROM #Data AS d
					) AS a
				WHERE a.RowNum BETWEEN @RowStart AND @RowEnd
				ORDER BY a.RowNum ASC'

			INSERT INTO #PagingData
			(
				RowNum, TransId, RefNo, CustId, Currency, Recommend, SportType, BetType, BetId, BetTeam,
				Hdp1, Hdp2, OddsId, OddsType, Odds, MOdds, OddsSpread, Stake, Actual_Stake, Status,
				SettlementStatus, SecAcceptFlag, CheckTime, TransDate, WinLostDate, LiveIndicator, LiveHomeScore, LiveAwayScore, Ip, BetFrom,
				LeagueId, LeagueGroupId, MatchId, MatchCode, Race, EventDate, HomeId, AwayId, BetStatus, IsNeutral,
				Placing, ShowTime, BetCheck, ComStatus, TransDesc, BetdaqId, ExtraInfo, OriginalStake, OriginalBetType, WalletType,
				RefCode, ProductId, Custom1, Custom2, Custom3, Gameid3rd, Tranid3rd, TableID, Product, RefTable,
				EventType
			)
			EXEC sp_executesql @Sql, N'@RowStart INT, @RowEnd INT', @RowStart, @RowEnd;

			UPDATE p
			SET
				SportType = CASE
								WHEN p.Product IN ('VB', 'PP', 'CC', 'SG', 'OneRNG', 'Allbet', 'AG', 'SBC', 'SXG', 'SAG', 'PGS', 'JK', 
									'HB', 'WM', 'BG', 'VGA', 'CG', 'AP', 'APM', 'FGGL', 'MXG', 'JIG', 'YB', 'MGRNG', 'SEA') THEN p.MatchId
								WHEN p.Product IN ('Keno', 'Lottery', 'VRG', 'TG', 'I4D', 'H5LG', 'SLT', 'VS3') THEN p.ProductId
								WHEN p.Product IN ('Outright') THEN l.sporttype
								WHEN p.EventType = 1 THEN m.sporttype
								WHEN p.EventType = 3 THEN vr.SportType
								WHEN p.EventType = 5 THEN m3rd.SportType
								WHEN p.RefTable IN (1, 2) THEN p.MatchId
								ELSE 0
							END,
				Stake = CASE
							WHEN p.RefTable IN (1, 2) AND x.Stake IS NOT NULL THEN x.Stake
							ELSE p.stake 
						END,
				Actual_Stake = CASE
									WHEN p.RefTable IN (1, 2) AND x.Actual_Stake IS NOT NULL THEN x.Actual_Stake
									ELSE p.actual_stake
								END,
				Status = CASE
							WHEN p.RefTable IN (1, 2) AND x.RefNo IS NOT NULL THEN 'Running'
							WHEN p.Product = 'SB'
								AND p.status = 'running' AND ISNULL(p.SecAcceptFlag, 0) = 1 AND ISNULL(p.checktime, CURRENT_TIMESTAMP) > CURRENT_TIMESTAMP THEN 'waiting'
							WHEN p.Product = 'Parlay' AND p.status = 'running' THEN
								CASE
									WHEN EXISTS (SELECT 1 FROM dbo.bettransm AS bm WITH (NOLOCK)
												WHERE bm.custid = p.custid
													AND bm.refno = p.refno
													AND (bm.status = 'waiting'
														OR (bm.status = 'running' AND ISNULL(bm.SecAcceptFlag, 0) = 1 AND ISNULL(bm.checktime, CURRENT_TIMESTAMP) > CURRENT_TIMESTAMP)))
										THEN 'Waiting'
									ELSE p.status
								END
							ELSE p.status
						END,
				SettlementStatus = CASE
										WHEN p.Product IN ('SB') THEN ISNULL(m.SettlementStatus, 0)
										ELSE 0
									END,
				LeagueId = CASE
								WHEN p.EventType = 1 THEN m.leagueid
								WHEN p.EventType = 5 THEN m3rd.League3rdId
								WHEN p.Product IN ('Outright') THEN o.leagueid
								WHEN p.EventType = 3 THEN vr.LeagueID
								ELSE 0
							END,
				LeagueGroupId = CASE
									WHEN p.Product IN ('SB') THEN le.LeagueGroupID
									ELSE 0
								END,
				MatchCode = CASE
								WHEN p.EventType = 1 THEN m.matchcode
								WHEN p.Product IN ('Outright') THEN o.matchcode
								ELSE ''
							END,
				Race = CASE
							WHEN p.Product IN ('Outright') THEN o.groupmatch
							ELSE ''
						END,
				EventDate = CASE
								WHEN p.Product IN ('SB') THEN m.GlobalShowTime
								WHEN p.Product IN ('BTC') THEN m3rd.EndTime
								ELSE p.WinLostDate
							END,
				HomeId = CASE
							WHEN p.EventType = 1 THEN m.homeid
							WHEN p.EventType = 5 THEN m3rd.HomeId
							WHEN p.Product IN ('Outright') THEN o.teamid
							ELSE 0
						END,
				AwayId = CASE
							WHEN p.EventType = 1 THEN m.awayid
							WHEN p.EventType = 5 THEN m3rd.AwayId
							ELSE 0
						END,
				BetStatus = CASE
								WHEN p.EventType = 1 THEN m.betstatus
								ELSE ''
							END,
				IsNeutral = CASE
								WHEN p.EventType = 1 THEN ISNULL(m.IsNeutral, 0)
								ELSE 0
							END,
				Placing = '',
				ShowTime = CASE
								WHEN p.Product IN ('VS') THEN CONVERT(NVARCHAR(50), m.kickofftime)
								WHEN p.EventType = 5 THEN CONVERT(NVARCHAR(50), m3rd.StartTime)
								ELSE ''
							END,
				BetCheck = CASE
								WHEN p.Product IN ('Keno') THEN ISNULL(p.custom2, '')
								WHEN p.Product IN ('VRG', 'SLT') THEN ISNULL(p.TranId3rd, '')
								WHEN p.Product IN ('H5LG') THEN ISNULL(p.Gameid3rd, '')
								WHEN p.Product IN ('SB') THEN ISNULL(p.betcheck, '')
								WHEN p.Product IN ('VS3') THEN ISNULL(p.custom1, '')
								WHEN p.EventType = 0 AND p.RefTable = 0 THEN ISNULL(p.betcheck, '')
								ELSE ''
							END,
				TransDesc = CASE
								WHEN p.Product IN ('Keno', 'Lottery', 'OneRNG', 'VB', 'PP', 
									'CC', 'SG', 'VRG', 'TG', 'PGS', 'JK', 'H5LG', 'SLT', 'HB', 'CG', 'AP', 'APM', 'SEA') THEN ISNULL(p.transdesc, '')
								WHEN p.BetType = 29 AND p.OddsSpread = 3 THEN ISNULL(p.transdesc, '')
								WHEN p.EventType IN (1, 3, 5) THEN ISNULL(p.transdesc, '')
								ELSE ''
							END,
				OddsSpread = CASE
								WHEN p.Product IN ('SB') THEN ISNULL(p.oddsspread, 0)
								WHEN p.BetType = 29 AND p.OddsSpread = 3 THEN p.OddsSpread
								ELSE 0
							END,
				BetdaqId = CASE
								WHEN p.Product IN ('SB') THEN ISNULL(p.betdaqid, -1)
								ELSE -1
							END,
				ExtraInfo = CASE
								WHEN p.Product IN ('SB', 'Parlay', 'Outright', 'NG', 'VS', 'VS2', 'ParlayVS2', 'VR', 'BTC', 'LG') THEN ISNULL(p.ExtraInfo, '')
								ELSE ''
							END,
				OriginalStake = 0,
				OriginalBetType = CASE
									WHEN p.Product IN ('SB') AND p.stake <> 0 THEN -1
									ELSE 0
								END,
				WalletType = CASE
								WHEN p.Product IN ('SB') THEN ISNULL(p.WalletType, 0)
								ELSE 0
							END,
				RefCode = CASE
								WHEN p.Product IN ('SB') AND p.stake <> 0 THEN ISNULL(p.RefCode, 0)
								ELSE 0
							END
			FROM #PagingData AS p
				LEFT JOIN @TmpData AS x
					ON p.RefTable IN (1, 2)
					AND p.Winlostdate >= @Yesterday
					AND x.RefNo = p.TransId
				LEFT JOIN dbo.match AS m WITH (NOLOCK) ON p.EventType = 1 AND p.matchid = m.matchid
				LEFT JOIN dbo.League AS le WITH (NOLOCK) ON p.Product IN ('SB') AND le.leagueid = m.leagueid
				LEFT JOIN dbo.match3rd AS m3rd WITH (NOLOCK) ON p.EventType = 5 AND m3rd.Match3rdId = p.matchid
				LEFT JOIN dbo.outright AS o WITH (NOLOCK) ON p.Product IN ('Outright') AND p.matchid = o.orid
				LEFT JOIN dbo.League AS l WITH (NOLOCK) ON p.Product IN ('Outright') AND o.leagueID = l.leagueID
				LEFT JOIN dbo.VSRaceInfo AS vr WITH (NOLOCK) ON p.EventType = 3 AND vr.EventID = p.matchid
		END
	END

	SELECT
		r.TransId,
		r.RefNo,
		r.CustId,
		r.Currency,
		r.SportType,
		r.BetType,
		r.BetId,
		r.BetTeam,
		r.Hdp1,
		r.Hdp2,
		r.OddsId,
		r.OddsType,
		r.Odds,
		r.MOdds,
		r.OddsSpread,
		r.Stake,
		r.Actual_Stake,
		r.Status,
		r.SettlementStatus,
		r.SecAcceptFlag,
		r.CheckTime,
		r.TransDate,
		r.WinLostDate,
		r.LiveIndicator,
		r.LiveHomeScore,
		r.LiveAwayScore,
		r.Ip,
		r.BetFrom,
		r.LeagueId,
		r.LeagueGroupId,
		r.MatchId,
		r.MatchCode,
		r.Race,
		r.EventDate,
		r.HomeId,
		r.AwayId,
		r.BetStatus,
		r.IsNeutral,
		r.Placing,
		r.ShowTime,
		r.BetCheck,
		r.ComStatus,
		r.TransDesc,
		r.BetdaqId,
		r.ExtraInfo,
		r.OriginalStake,
		r.OriginalBetType,
		r.WalletType,
		r.RefCode
	FROM #PagingData r
	ORDER BY RowNum ASC

	SELECT DISTINCT
		d.RefNo,
		d.Odds,
		d.Stake,
		d.Status,
		d.BetType,
		d.BetTeam
	FROM @Detail d

	DROP TABLE #Data
	DROP TABLE #PagingData
END
GO
