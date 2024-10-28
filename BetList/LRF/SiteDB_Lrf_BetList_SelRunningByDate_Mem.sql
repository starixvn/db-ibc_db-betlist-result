/*<info serverAlias="DBSID-bodb02" executers="wsv_lap" isFunction="0" isNested="0"></info>*/

ALTER PROCEDURE [dbo].[SiteDB_Lrf_BetList_SelRunningByDate_Mem]
	@AgentList		VARCHAR(MAX),
	@CustId			INT			= NULL,
	@Username		VARCHAR(30)	= NULL, -- for API
	@FromDate		DATETIME	= '',
	@ToDate			DATETIME	= '',
	@ProductList	VARCHAR(200)	= '',
	@ShowBA			BIT				= 0,	-- BA
	@ExcludeFreeBet	BIT				= 0,	-- Exclude free tickets
	@BaseCurrency	VARCHAR(12),
	@PageSize		INT				= 1000,
	@PageIndex		INT				= 1,
	@TotalRows		INT				= 0		OUTPUT
AS

/*
	Created: 20220727@Kos
	Task: LAP - Outstanding Report Bet list - SiteDB
	DB: DBSID.bodb02

	Revisions:
		- 20220727@Kos: Created [Redmine: #175297]
		- 20220922@Kos: Support crypto currency [Redmine: 177481]
		- 20230119@Kos: Support Jili [Redmine: 182914]
		- 20230328@Kos: Remove inactive products CB, FW, GDG [Redmine: 181424]
		- 20230602@Kos: Support YeeBet [Redmine: 187947]
		- 20230629@Kos: Support MG-RNG [Redmine: 189988]
		- 20230803@Kos: Support Virtual Sports 3 [Redmine: 190908]
		- 20231107@Kos: Support SEAL Entertaiment [Redmine: 180648]
					- Remove param @ErrorCode, @ErrorMsg, @ShowSB, @ShowNG, ...
					- Add new input param @ProductList VARCHAR(300)
		- 20231215@Kos: Hotfix - not convert to base currency [Redmine: 198461]
		- 20231225@Kos: Support WE Live Casino [Redmine: 196573]
		- 20231227@Kos: Hotfix - cannot view result [Redmine: 198900]
		- 20240102@Kos: Extend data type [Redmine: 198966]
		- 20240129@Kos: Merge VS1, VS2, VS3 into VS [Redmine: 199523]
		- 20240412@Kos: Support Gaming API [Redmine: 203734]
		- 20240425@Kos: Return LeagueGroupId to support Jollysports [Redmine: #203258]
		- 20240605@Kos: Support Virtual Sports 4 [Redmine: 199347]
		- 20240919@Kos: Support BetRadar Horse Racing [Redmine: #210808]
		- 20241028@Kos: Support Virtual Sports 6 [Redmine: 212446]
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

	DECLARE @ShowSB BIT = 0

	IF ',' + @ProductList + ',' LIKE '%,SB,%'
	BEGIN
		SET @ShowSB = 1
	END

	IF @ShowBA = 1
	BEGIN
		SET @ProductList = 'SB,' + @ProductList
	END

	-- Get child product list
	IF EXISTS (SELECT 1 FROM dbo.Lrf_f_GroupProduct() WHERE ',' + @ProductList + ',' LIKE '%,' + GroupProductPrefix + ',%')
	BEGIN
		DECLARE @ChildProductList VARCHAR(500)

		SELECT @ChildProductList = STRING_AGG(ProductPrefix, ',')
		FROM dbo.Lrf_f_GroupProduct()
		WHERE ',' + @ProductList + ',' LIKE '%,' + GroupProductPrefix + ',%'

		SET @ProductList = @ProductList + ',' + @ChildProductList
	END

	-- Get SportBetTypeMatrix
	DECLARE @SportBettype TABLE (ProductId TINYINT, BetType SMALLINT, EventType TINYINT, RefTable TINYINT)

	DECLARE @IsTest BIT = 0

	SELECT @IsTest = dbo.f_CheckSPVersion(@@PROCID)

	INSERT INTO @SportBettype
	SELECT ProductID, BetType, EventType, RefTable
	FROM dbo.f_SportBettypeMatrix_Sel (0, 0, 0, 2, '', @ProductList, @IsTest)
	WHERE BetType NOT IN (71, 72, 73, 801, 802, 803, 804, 805, 806, 901, 902, 903, 904)

	IF @HasError = 0
	BEGIN
		IF @CustId IS NULL
		BEGIN
			SET @CustId = -1

			SELECT @CustId = custid
			FROM CustDB.dbo.Customer AS c WITH (NOLOCK)
			WHERE c.username = @Username
		END
		ELSE
		BEGIN
			SELECT @Username = CASE WHEN @Username IS NULL THEN username ELSE @Username END
			FROM CustDB.dbo.Customer WITH (NOLOCK)
			WHERE custid = @CustId
		END

		IF @CustId <> 0
			AND NOT EXISTS (	SELECT 1 FROM CustDB.dbo.custInfo AS c WITH (NOLOCK)
								WHERE c.custid = @CustId
									AND EXISTS (	SELECT 1 FROM @TempAg
													WHERE CustId = c.recommend AND Currency = c.currency))
		BEGIN
			SET @HasError = 1
		END
	END

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
			TransId,
			RefNo,
			CustId,
			Currency,
			Recommend,
			BetType,
			BetId,
			BetTeam,
			Hdp1,
			Hdp2,
			OddsId,
			OddsType,
			Odds,
			MOdds,
			OddsSpread,
			Stake,
			Actual_Stake,
			Status,
			SecAcceptFlag,
			CheckTime,
			TransDate,
			WinLostDate,
			LiveIndicator,
			LiveHomeScore,
			LiveAwayScore,
			Ip,
			BetFrom,
			MatchId,
			BetCheck,
			ComStatus,
			TransDesc,
			BetdaqId,
			ExtraInfo,
			WalletType,
			RefCode,
			TableID)
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
		WHERE b.custid = @CustId
			AND b.statusID IN (0, 1)
			AND b.transdate BETWEEN @FromDate AND @ToDate

		-- translog
		INSERT INTO #Data (
			TransId,
			RefNo,
			CustId,
			Currency,
			Recommend,
			BetType,
			Odds,
			Stake,
			Actual_Stake,
			Status,
			TransDate,
			WinLostDate,
			LiveIndicator,
			Ip,
			BetFrom,
			TransDesc,
			ProductId,
			Custom1,
			Custom2,
			Custom3,
			Gameid3rd,
			Tranid3rd,
			TableID
		)
		SELECT
			b.translogid AS TransId,
			b.translogid AS RefNo,
			b.custid,
			b.currency,
			b.recommend,
			b.gameID AS BetType,
			b.odds,
			b.stake,
			b.actual_stake,
			b.status,
			b.transdate,
			b.transdate AS WinLostDate,
			b.LiveIndicator,
			b.ip,
			b.betfrom,
			b.transdesc,
			b.productID,
			b.custom1,
			b.custom2,
			b.custom3,
			b.GameId3rd,
			b.TranId3rd,
			2 AS TableID
		FROM dbo.translog AS b WITH (NOLOCK)
		WHERE b.custid = @CustId
			AND b.statusID IN (0, 1)
			AND b.transdate BETWEEN @FromDate AND @ToDate

		DELETE b
		FROM #Data AS b
		WHERE NOT EXISTS (SELECT 1 FROM @TempAg WHERE CustId = b.Recommend AND Currency = b.Currency)

		-- Get Sport/Bettype info
		UPDATE b
		SET
			Product = CASE
						WHEN s.ProductId = 6 THEN 'OneRNG'							-- RNG Casino
						WHEN s.ProductId = 8 THEN 'Keno'
						WHEN s.ProductId = 11 THEN 'AG'								-- AG Casino
						WHEN s.ProductId = 15 THEN 'CB'								-- Colossus Bet
						WHEN s.ProductId = 21 THEN 'AllBet'
						WHEN s.ProductId = 22 THEN 'VB'								-- Macau Games
						WHEN s.ProductId = 24 THEN 'FW'								-- Fishing World
						WHEN s.ProductId = 28 THEN 'Lottery'
						WHEN s.ProductId = 32 THEN 'PP'								-- Pragmatic Play Casino
						WHEN s.ProductId = 34 THEN 'CC'								-- Card Club
						WHEN s.ProductId = 36 THEN 'SG'								-- Spadegaming
						WHEN s.ProductId = 38 THEN 'VRG'							-- Virtual Games
						WHEN s.ProductId = 39 THEN 'SAG'							-- SA Gaming
						WHEN s.ProductId = 40 THEN 'TG'								-- Table Games
						WHEN s.ProductId = 42 THEN 'SBC'							-- Saba.club
						WHEN s.ProductId = 43 THEN 'I4D'							-- Indo 4D
						WHEN s.ProductId = 45 THEN 'SXG'							-- Sexy Gaming
						WHEN s.ProductId = 49 THEN 'VS3'							-- Virtual Sports 3
						WHEN s.ProductId = 51 THEN 'WM'								-- WM Live Casino
						WHEN s.ProductId = 55 THEN 'PGS'							-- PG Soft
						WHEN s.ProductId = 56 THEN 'JK'								-- Joker
						WHEN s.ProductId = 57 THEN 'BG'								-- Big Gaming
						WHEN s.ProductId = 59 THEN 'GDG'							-- GDG
						WHEN s.ProductId = 60 THEN 'MXG'							-- MaxGame
						WHEN s.ProductId = 61 THEN 'HB'								-- Habanero
						WHEN s.ProductId = 62 THEN 'CG'								-- CG
						WHEN s.ProductId = 63 THEN 'SLT'							-- Sports Lottery
						WHEN s.ProductId = 66 THEN 'VGA'							-- Vgaming
						WHEN s.ProductId = 67 THEN 'AP'								-- AdvantPlay
						WHEN s.ProductId = 68 THEN 'APM'							-- AdvantPlay Mini
						WHEN s.ProductId = 69 THEN 'BTC'							-- Bitcoin
						WHEN s.ProductId = 70 THEN 'FGGL'							-- FGG
						WHEN s.ProductId = 72 THEN 'SEA'							-- SEAL Entertainment
						WHEN s.EventType = 0 AND s.ProductId = 1 THEN 'Parlay'		-- Sportsbook Parlay
						WHEN s.EventType = 0 AND s.ProductId = 3 THEN 'H5LG'		-- Happy 5 Linked Games (Number Game)
						WHEN s.EventType = 0 AND s.ProductId = 27 THEN 'ParlayVS2'	-- Betradar Virtual Sports Parlay
						WHEN s.EventType = 1 AND s.ProductId = 1 THEN 'SB'			-- Sportsbook
						WHEN s.EventType = 1 AND s.ProductId = 3 THEN 'NG'			-- Number Game
						WHEN s.EventType = 1 AND s.ProductId = 5 THEN 'VS'			-- Virtual Sports Sportsbook
						WHEN s.EventType = 1 AND s.ProductId = 27 THEN 'VS2'		-- Betradar Virtual Sports
						WHEN s.EventType = 2 AND s.ProductId = 1 THEN 'Outright'
						ELSE 'Unknown'
					END,
			RefTable = s.RefTable,
			EventType = s.EventType
		FROM #Data AS b
			INNER JOIN @SportBettype AS s ON s.BetType = b.bettype

		DELETE #Data
		WHERE Product IS NULL

		DECLARE @Yesterday SMALLDATETIME = DATEADD(DAY, DATEDIFF(DAY, 1, CURRENT_TIMESTAMP), 0)

		-- bettransRnG
		INSERT INTO @TmpData
		SELECT
			b.RefNo,
			b.gameID AS BetType,
			SUM(b.stake) AS Stake,
			SUM(b.actual_stake) AS Actual_Stake,
			1 AS IsNew
		FROM dbo.bettransRnG AS b WITH (NOLOCK)
			INNER JOIN @SportBettype AS s ON s.BetType = b.gameID
		WHERE b.custid = @CustId
			AND b.winlostdate >= @Yesterday
			AND b.statusID IN (0, 1)
			AND s.RefTable = 1
		GROUP BY b.RefNo,
			b.gameID

		-- bettransLC
		INSERT INTO @TmpData
		SELECT
			b.RefNo,
			b.gameID AS BetType,
			SUM(b.stake) AS Stake,
			SUM(b.actual_stake) AS Actual_Stake,
			1 AS IsNew
		FROM dbo.bettransLC AS b WITH (NOLOCK)
			INNER JOIN @SportBettype AS s ON s.BetType = b.gameID
		WHERE b.custid = @CustId
			AND b.winlostdate >= @Yesterday
			AND b.statusID IN (0, 1)
			AND s.RefTable = 2
		GROUP BY b.RefNo,
			b.gameID

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
			TransId,
			RefNo,
			CustId,
			Currency,
			Recommend,
			BetType,
			BetId,
			BetTeam,
			Hdp1,
			Hdp2,
			OddsId,
			OddsType,
			Odds,
			MOdds,
			OddsSpread,
			Stake,
			Actual_Stake,
			Status,
			SecAcceptFlag,
			CheckTime,
			TransDate,
			WinLostDate,
			LiveIndicator,
			LiveHomeScore,
			LiveAwayScore,
			Ip,
			BetFrom,
			MatchId,
			BetCheck,
			ComStatus,
			TransDesc,
			BetdaqId,
			ExtraInfo,
			WalletType,
			RefCode,
			TableID,
			Product,
			RefTable)
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
			1 AS TableID,
			CASE
				WHEN s.ProductID = 6 THEN 'OneRNG'	-- RNG Casino
				WHEN s.ProductID = 11 THEN 'AG'		-- AG Casino
				WHEN s.ProductID = 21 THEN 'AllBet'
				WHEN s.ProductID = 22 THEN 'VB'		-- Macau Games
				WHEN s.ProductID = 24 THEN 'FW'		-- Fishing World
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
				WHEN s.ProductID = 59 THEN 'GDG'	-- GDG
				WHEN s.ProductID = 60 THEN 'MXG'	-- MaxGame
				WHEN s.ProductID = 61 THEN 'HB'		-- Habanero
				WHEN s.ProductID = 62 THEN 'CG'		-- CG
				WHEN s.ProductID = 66 THEN 'VGA'	-- Vgaming
				WHEN s.ProductID = 67 THEN 'AP'		-- AdvantPlay
				WHEN s.ProductID = 68 THEN 'APM'	-- AdvantPlay Mini
				WHEN s.ProductID = 70 THEN 'FGGL'	-- FGG
				WHEN s.ProductId = 72 THEN 'SEA'	-- SEAL Entertainment
				ELSE 'Unknown'
			END AS Product,
			s.RefTable
		FROM dbo.bettrans AS b WITH (NOLOCK)
			INNER JOIN @TmpData AS t ON t.RefNo = b.transid AND t.BetType = b.BetType
			INNER JOIN @SportBettype AS s ON s.BetType = b.bettype
		WHERE b.custid = @CustId
			AND t.IsNew = 1

		IF @ExcludeFreeBet = 1
		BEGIN
			-- Exclude Saba.club Free Bet
			DELETE FROM #Data
			WHERE Product = 'SBC' AND MatchId = 150
		END

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
				INSERT INTO @RefCodeTmp
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
			SELECT @TotalRows = COUNT(1)
			FROM #Data AS b

			INSERT INTO #PagingData
			SELECT
				ROW_NUMBER() OVER(ORDER BY TransDate DESC) AS RowNum,
				*
			FROM #Data
			ORDER BY TransDate DESC
			OFFSET @PageSize * (@PageIndex - 1) ROWS
			FETCH NEXT @PageSize ROWS ONLY

			UPDATE b
			SET
				TransId = CASE
							WHEN b.Product = 'Parlay' AND b.BetType = 29 AND ISNULL(b.BetId, 0) > 0 THEN b.BetId
							ELSE b.TransId
						END,
				SportType = CASE
								WHEN b.Product IN ('VB', 'FW', 'PP', 'CC', 'SG', 'OneRNG', 'Allbet', 'AG', 'CB', 'SBC', 'SXG', 'SAG', 'PGS', 'JK', 
									'GDG', 'HB', 'WM', 'BG', 'VGA', 'CG', 'AP', 'APM', 'FGGL', 'MXG', 'SEA') THEN b.MatchId
								WHEN b.Product IN ('Keno', 'Lottery', 'VRG', 'TG', 'I4D', 'H5LG', 'SLT', 'VS3') THEN b.ProductId
								WHEN b.EventType = 1 THEN m.sporttype
								WHEN b.EventType = 5 THEN m3rd.SportType
								WHEN b.Product IN ('Outright') THEN l.sporttype
								WHEN b.EventType = 3 THEN vr.SportType
								WHEN b.RefTable IN (1, 2) THEN b.MatchId
								ELSE 0
							END,
				Stake = CASE
							WHEN b.RefTable IN (1, 2) AND x.Stake IS NOT NULL THEN x.Stake
							ELSE b.stake 
						END,
				Actual_Stake = CASE
									WHEN b.RefTable IN (1, 2) AND x.Actual_Stake IS NOT NULL THEN x.Actual_Stake
									ELSE b.actual_stake
								END,
				Status = CASE
							WHEN b.RefTable IN (1, 2) AND x.RefNo IS NOT NULL THEN 'Running'
							WHEN b.Product = 'SB'
								AND b.status = 'running' AND ISNULL(b.SecAcceptFlag, 0) = 1 AND ISNULL(b.checktime, CURRENT_TIMESTAMP) > CURRENT_TIMESTAMP THEN 'waiting'
							WHEN b.Product = 'Parlay' AND b.status = 'running' THEN
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
						END,
				SettlementStatus = CASE
										WHEN b.Product IN ('SB') THEN ISNULL(m.SettlementStatus, 0)
										ELSE 0
									END,
				LeagueId = CASE
								WHEN b.EventType = 1 THEN m.leagueid
								WHEN b.EventType = 5 THEN m3rd.League3rdId
								WHEN b.Product IN ('Outright') THEN o.leagueid
								WHEN b.EventType = 3 THEN vr.LeagueID
								ELSE 0
							END,
				LeagueGroupId = CASE
										WHEN b.Product IN ('SB') THEN le.LeagueGroupID
										ELSE 0
									END,
				MatchId = CASE
								WHEN b.EventType IN (1, 5) THEN b.matchid
								WHEN b.Product IN ('VR', 'BTC') THEN b.matchid
								ELSE 0
							END,
				MatchCode = CASE
								WHEN b.EventType = 1 THEN m.matchcode
								WHEN b.Product IN ('Outright') THEN o.matchcode
								ELSE ''
							END,
				Race = CASE
							WHEN b.Product IN ('Outright') THEN o.groupmatch
							ELSE ''
						END,
				EventDate = CASE
								WHEN b.Product IN ('SB') THEN m.GlobalShowTime
								WHEN b.Product IN ('BTC') THEN m3rd.EndTime
								ELSE b.WinLostDate
							END,
				HomeId = CASE
							WHEN b.EventType = 1 THEN m.homeid
							WHEN b.EventType = 5 THEN m3rd.HomeId
							WHEN b.Product IN ('Outright') THEN o.teamid
							ELSE 0
						END,
				AwayId = CASE
							WHEN b.EventType = 1 THEN m.awayid
							WHEN b.EventType = 5 THEN m3rd.AwayId
							ELSE 0
						END,
				BetStatus = CASE
								WHEN b.EventType = 1 THEN m.betstatus
								ELSE ''
							END,
				IsNeutral = CASE
								WHEN b.EventType = 1 THEN ISNULL(m.IsNeutral, 0)
								ELSE 0
							END,
				Placing = '',
				ShowTime = CASE
								WHEN b.Product IN ('VS') THEN CONVERT(NVARCHAR(50), m.kickofftime)
								WHEN b.EventType = 5 THEN CONVERT(NVARCHAR(50), m3rd.StartTime)
								ELSE ''
							END,
				BetCheck = CASE
								WHEN b.Product IN ('Keno') THEN ISNULL(b.custom2, '')
								WHEN b.Product IN ('VRG', 'SLT') THEN ISNULL(b.TranId3rd, '')
								WHEN b.Product IN ('H5LG') THEN ISNULL(b.Gameid3rd, '')
								WHEN b.Product IN ('SB') THEN ISNULL(b.betcheck, '')
								WHEN b.Product IN ('VS3') THEN ISNULL(b.custom1, '')
								WHEN b.EventType = 0 AND b.RefTable = 0 THEN ISNULL(b.betcheck, '')
								ELSE ''
							END,
				TransDesc = CASE
								WHEN b.Product IN ('Keno', 'Lottery', 'OneRNG', 'VB', 'FW', 'PP', 
									'CC', 'SG', 'VRG', 'TG', 'I4D', 'PGS', 'JK', 'H5LG', 'SLT', 'HB', 'CG', 'AP', 'APM', 'SEA') THEN ISNULL(b.transdesc, '')
								WHEN b.EventType IN (1, 3) THEN ISNULL(b.transdesc, '')
								ELSE ''
							END,
				OddsSpread = CASE
								WHEN b.Product IN ('SB') THEN ISNULL(b.oddsspread, 0)
								ELSE 0
							END,
				BetdaqId = CASE
								WHEN b.Product IN ('SB') THEN ISNULL(b.betdaqid, -1)
								ELSE -1
							END,
				ExtraInfo = CASE
								WHEN b.EventType IN (0, 1) THEN ISNULL(b.ExtraInfo, '')
								WHEN b.Product IN ('Outright', 'VR', 'BTC') THEN ISNULL(b.ExtraInfo, '')
								ELSE ''
							END,
				OriginalStake = 0,
				OriginalBetType = CASE
									WHEN b.Product IN ('SB') AND b.stake <> 0 THEN -1
									ELSE 0
								END,
				WalletType = CASE
								WHEN b.Product IN ('SB') THEN ISNULL(b.WalletType, 0)
								ELSE 0
							END,
				RefCode = CASE
								WHEN b.Product IN ('SB') AND b.stake <> 0 THEN ISNULL(b.RefCode, 0)
								ELSE 0
							END
			FROM #PagingData AS b
				LEFT JOIN @TmpData AS x
					ON b.RefTable IN (1, 2)
					AND b.Winlostdate >= @Yesterday
					AND x.RefNo = b.TransId
				LEFT JOIN dbo.match AS m WITH (NOLOCK) ON b.EventType = 1 AND b.matchid = m.matchid
				LEFT JOIN dbo.League AS le WITH (NOLOCK) ON b.Product IN ('SB') AND le.leagueid = m.leagueid
				LEFT JOIN dbo.match3rd AS m3rd WITH (NOLOCK) ON b.EventType = 5 AND m3rd.Match3rdId = b.matchid
				LEFT JOIN dbo.outright AS o WITH (NOLOCK) ON b.Product IN ('Outright') AND b.matchid = o.orid
				LEFT JOIN dbo.League AS l WITH (NOLOCK) ON b.Product IN ('Outright') AND o.leagueID = l.leagueID
				LEFT JOIN dbo.VSRaceInfo AS vr WITH (NOLOCK) ON b.EventType = 3 AND vr.EventID = b.matchid
		END
	END

	-- Get exchange rate
	CREATE TABLE #ExchangeRate (
		ExchangeId	INT,
		Rate		FLOAT
	)

	-- Get exchange rate
	INSERT INTO #ExchangeRate
	SELECT
		e.ExchangeId,
		e.Rate
	FROM dbo.SiteDB_Lrf_f_GetExchangeRate(DATEADD(DAY, DATEDIFF(DAY, 0, GETDATE()), 0), DATEADD(DAY, DATEDIFF(DAY, 0, GETDATE()), 0), @BaseCurrency, '') AS e
	WHERE EXISTS (SELECT 1 FROM #PagingData WHERE Currency = e.ExchangeId)

	SELECT
		a.TransId,
		a.RefNo,
		a.CustId,
		a.Currency,
		a.SportType,
		a.BetType,
		a.BetId,
		a.BetTeam,
		a.Hdp1,
		a.Hdp2,
		a.OddsId,
		a.OddsType,
		a.Odds,
		a.MOdds,
		a.OddsSpread,
		a.Stake * ISNULL(e.Rate, 1) AS Stake,
		a.Actual_Stake * ISNULL(e.Rate, 1) AS Actual_Stake,
		a.Status,
		a.SettlementStatus,
		a.SecAcceptFlag,
		a.CheckTime,
		a.TransDate,
		a.WinLostDate,
		a.LiveIndicator,
		a.LiveHomeScore,
		a.LiveAwayScore,
		a.Ip,
		a.BetFrom,
		a.LeagueId,
		a.LeagueGroupId,
		a.MatchId,
		a.MatchCode,
		a.Race,
		a.EventDate,
		a.HomeId,
		a.AwayId,
		a.BetStatus,
		a.IsNeutral,
		a.Placing,
		a.ShowTime,
		a.BetCheck,
		a.ComStatus,
		a.TransDesc,
		a.BetdaqId,
		a.ExtraInfo,
		a.OriginalStake * ISNULL(e.Rate, 1) AS OriginalStake,
		a.OriginalBetType,
		a.WalletType,
		a.RefCode
	FROM #PagingData AS a
		LEFT JOIN #ExchangeRate AS e ON e.ExchangeId = a.Currency
	ORDER BY RowNum ASC

	SELECT DISTINCT * FROM @Detail

	DROP TABLE #Data
	DROP TABLE #PagingData
END
GO
