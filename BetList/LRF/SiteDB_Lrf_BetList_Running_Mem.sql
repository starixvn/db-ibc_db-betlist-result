/*<info serverAlias="DBSID-bodb02" executers="bodbLicenseeNet" viewers="" isFunction="0" isNested="0"></info>*/

ALTER PROCEDURE [dbo].[SiteDB_Lrf_BetList_Running_Mem]
	@AgentList	VARCHAR(MAX),
	@CustId		INT,
	@PageSize	INT				= 1000,
	@PageIndex	INT				= 1,
	@Sort		NVARCHAR(50)	= N'TransDate DESC',
	@TotalRows	INT				= 0 OUTPUT,
	@SumStake	MONEY			= 0 OUTPUT
AS

/*
	Created: 20220727@Kos
	Task: Player Admin - Running Bet List - SiteDB
	DB: DBSID.bodb02

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
		Tranid3rd			NVARCHAR(64),
		TableID				TINYINT,
		Product				VARCHAR(30),
		RefTable			TINYINT
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
		Tranid3rd			NVARCHAR(64),
		TableID				TINYINT,
		Product				VARCHAR(30),
		RefTable			TINYINT
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
		WHERE b.custid = @CustId AND b.statusID IN (0, 1)

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
		WHERE b.custid = @CustId AND b.statusID IN (0, 1)

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
						WHEN s.EventType = 3 AND s.ProductID = 5 THEN 'VR'			-- Virtual Sports Racing
						ELSE 'Unknown'
					END,
			RefTable = s.RefTable
		FROM #Data AS b
			INNER JOIN dbo.f_SportBettypeMatrix_Sel (0, 0, 0, 2, '', '', @IsTest) AS s ON b.bettype = s.bettype

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
			INNER JOIN dbo.f_SportBettypeMatrix_Sel (0, 0, 0, 2, '', '', @IsTest) AS s ON b.gameID = s.bettype
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
			INNER JOIN dbo.f_SportBettypeMatrix_Sel (0, 0, 0, 2, '', '', @IsTest) AS s ON b.gameID = s.bettype
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
			s.RefTable
		FROM dbo.bettrans AS b WITH (NOLOCK)
			INNER JOIN @TmpData AS t ON t.RefNo = b.transid AND t.BetType = b.BetType
			INNER JOIN dbo.f_SportBettypeMatrix_Sel (0, 0, 0, 2, '', '', @IsTest) AS s ON b.bettype = s.bettype
		WHERE b.custid = @CustId
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
			SELECT
				@TotalRows = COUNT(1),
				@SumStake = SUM(b.Stake)
			FROM #Data AS b

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
							ROW_NUMBER() OVER (ORDER BY ' + @Sort + N') AS RowNum,
							d.*
						FROM #Data AS d
					) AS a
				WHERE a.RowNum BETWEEN @RowStart AND @RowEnd
				ORDER BY a.RowNum'

			INSERT INTO #PagingData
			EXEC sp_executesql @Sql, N'@RowStart INT, @RowEnd INT', @RowStart, @RowEnd;

			UPDATE b
			SET
				TransId = CASE
							WHEN b.Product = 'Parlay' AND b.BetType = 29 AND ISNULL(b.BetId, 0) > 0 THEN b.BetId
							ELSE b.TransId
						END,
				SportType = CASE
								WHEN b.Product IN ('VB', 'PP', 'CC', 'SG', 'OneRNG', 'Allbet', 'AG', 'SBC', 'SXG', 'SAG', 'PGS', 'JK', 
									'HB', 'WM', 'BG', 'VGA', 'CG', 'AP', 'APM', 'FGGL', 'MXG', 'JIG', 'YB', 'MGRNG', 'SEA') THEN b.MatchId
								WHEN b.RefTable IN (1, 2) THEN b.MatchId
								WHEN b.Product IN ('Keno', 'Lottery', 'VRG', 'TG', 'I4D', 'H5LG', 'SLT', 'VS3') THEN b.ProductId
								WHEN b.Product IN ('SB', 'NG', 'VS', 'VS2', 'LG') THEN m.sporttype
								WHEN b.Product IN ('BTC') THEN m3rd.SportType
								WHEN b.Product IN ('Outright') THEN l.sporttype
								WHEN b.Product IN ('VR') THEN vr.SportType
								ELSE 0
							END,
				BetTeam = CASE
								WHEN b.Product IN ('SB', 'NG', 'VS', 'VS2', 'Parlay', 'ParlayVS2', 'BTC', 'LG') THEN b.BetTeam
								ELSE ''
							END,
				Hdp1 = CASE
							WHEN b.Product IN ('SB', 'NG', 'VS', 'VS2', 'VR', 'Parlay', 'ParlayVS2', 'BTC', 'LG') THEN b.Hdp1
							ELSE 0
						END,
				Hdp2 = CASE
							WHEN b.Product IN ('SB', 'VS', 'VS2', 'VR', 'Parlay', 'ParlayVS2', 'LG') THEN b.Hdp2
							ELSE 0
						END,
				OddsType = CASE
							WHEN b.Product IN ('SB', 'NG', 'VS', 'VS2', 'Outright', 'VR', 'LG') THEN b.OddsType
							ELSE 0
						END,
				Odds = CASE
							WHEN b.Product IN ('SB', 'NG', 'VS', 'VS2', 'Outright', 'VR', 'Parlay', 'Keno', 'ParlayVS2', 'Lottery', 'VRG', 'TG', 'I4D', 
								'SLT', 'H5LG', 'VS3', 'BTC', 'LG') THEN b.Odds
							ELSE 0
						END,
				MOdds = CASE 
							WHEN b.Product IN ('SB', 'NG', 'VS', 'VS2', 'Outright', 'VR', 'Parlay', 'ParlayVS2', 'LG') THEN b.modds
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
				LiveIndicator = CASE
									WHEN b.Product IN ('SB', 'NG', 'VS', 'VS2', 'LG') THEN b.liveindicator
									ELSE 0
								END,
				LiveHomeScore = CASE
									WHEN b.Product IN ('SB', 'NG', 'VS', 'VS2', 'Outright', 'VR', 'Parlay', 'ParlayVS2', 'LG') THEN b.livehomescore
									ELSE 0
								END,
				LiveAwayScore = CASE
									WHEN b.Product IN ('SB', 'NG', 'VS', 'VS2', 'Outright', 'VR', 'LG') THEN b.liveawayscore
									ELSE 0
								END,
				LeagueId = CASE
								WHEN b.Product IN ('SB', 'NG', 'VS', 'VS2', 'LG') THEN m.leagueid
								WHEN b.Product IN ('Outright') THEN o.leagueid
								WHEN b.Product IN ('VR') THEN vr.LeagueID
								ELSE 0
							END,
				MatchId = CASE
								WHEN b.Product IN ('SB', 'NG', 'VS', 'VS2', 'VR', 'BTC', 'LG') THEN b.matchid
								ELSE 0
							END,
				MatchCode = CASE
								WHEN b.Product IN ('SB', 'NG', 'VS', 'VS2') THEN m.matchcode
								WHEN b.Product IN ('Outright') THEN o.matchcode
								WHEN b.Product IN ('VR') THEN CONVERT(NVARCHAR(50), vo.RacerNum)
								ELSE ''
							END,
				Race = CASE
							WHEN b.Product IN ('Outright') THEN o.groupmatch
							WHEN b.Product IN ('VR') THEN CONVERT(NVARCHAR(50), b.oddsid)
							ELSE ''
						END,
				EventDate = CASE
								WHEN b.Product IN ('SB') THEN m.GlobalShowTime
								WHEN b.Product IN ('BTC') THEN m3rd.EndTime
								ELSE b.WinLostDate
							END,
				HomeId = CASE
							WHEN b.Product IN ('SB', 'NG', 'VS', 'VS2', 'LG') THEN m.homeid
							WHEN b.Product IN ('Outright') THEN o.teamid
							WHEN b.Product IN ('VR') THEN vo.RacerID
							ELSE 0
						END,
				AwayId = CASE
							WHEN b.Product IN ('SB', 'NG', 'VS', 'VS2', 'LG') THEN m.awayid
							ELSE 0
						END,
				BetStatus = CASE
								WHEN b.Product IN ('SB', 'NG', 'VS', 'VS2', 'LG') THEN m.betstatus
								ELSE ''
							END,
				IsNeutral = CASE
								WHEN b.Product IN ('SB', 'NG', 'VS', 'VS2', 'LG') THEN ISNULL(m.IsNeutral, 0)
								ELSE 0
							END,
				Placing = CASE
								WHEN b.Product IN ('VR') THEN CONVERT(VARCHAR(5), vo.Placing)
								ELSE ''
							END,
				ShowTime = CASE
								WHEN b.Product IN ('VS', 'VS2') THEN CONVERT(NVARCHAR(50), m.kickofftime)
								WHEN b.Product IN ('VR') THEN CONVERT(NVARCHAR(50), vr.EventTime)
								ELSE ''
							END,
				BetCheck = CASE
								WHEN b.Product IN ('Parlay', 'ParlayVS2') THEN ISNULL(b.betcheck, '')
								WHEN b.Product IN ('Keno') THEN ISNULL(b.custom2, '')
								WHEN b.Product IN ('VRG', 'H5LG', 'SLT') THEN ISNULL(b.Gameid3rd, '')
								WHEN b.Product IN ('SB') THEN ISNULL(b.betcheck, '')
								WHEN b.Product IN ('VS3') THEN ISNULL(b.custom1, '')
								ELSE ''
							END,
				TransDesc = CASE
								WHEN b.Product IN ('SB', 'VS2', 'Keno', 'Lottery', 'OneRNG', 'VB', 'PP', 
									'CC', 'SG', 'VRG', 'TG', 'I4D', 'PGS', 'JK', 'H5LG', 'SLT', 'HB', 'CG', 'AP', 'APM', 'VS3', 'LG', 'SEA') THEN ISNULL(b.transdesc, '')
								WHEN b.RefTable IN (1, 2) THEN ISNULL(b.transdesc, '')
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
								WHEN b.Product IN ('SB', 'Parlay', 'Outright', 'NG', 'VS', 'VS2', 'ParlayVS2', 'VR', 'BTC', 'LG') THEN ISNULL(b.ExtraInfo, '')
								ELSE ''
							END,
				OriginalStake = CASE
									WHEN b.Product IN ('SB') AND b.ExtraInfo LIKE '%p25%' THEN
										ISNULL(CAST(('<xml>' + b.ExtraInfo + '</xml>') AS XML).value('data(/xml/p25/@s)[1]','MONEY'), 0)
									ELSE 0
								END,
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
				LEFT JOIN dbo.match AS m WITH (NOLOCK) ON b.Product IN ('SB', 'NG', 'VS', 'VS2', 'LG') AND b.matchid = m.matchid
				LEFT JOIN dbo.match3rd AS m3rd WITH (NOLOCK) ON b.Product IN ('BTC') AND m3rd.Match3rdId = b.matchid
				LEFT JOIN dbo.outright AS o WITH (NOLOCK) ON b.Product IN ('Outright') AND b.matchid = o.orid
				LEFT JOIN dbo.League AS l WITH (NOLOCK) ON b.Product IN ('Outright') AND o.leagueID = l.leagueID
				LEFT JOIN dbo.VSOutright AS vo WITH (NOLOCK) ON b.Product IN ('VR') AND b.oddsid = vo.Orid
				LEFT JOIN dbo.VSRaceInfo AS vr WITH (NOLOCK) ON b.Product IN ('VR') AND vr.EventID = vo.EventID
		END
	END

	-- Get ticket detail
	-- Virtual Sports
	IF EXISTS (SELECT 1 FROM #Data WHERE Product = 'VR')
	BEGIN
		INSERT INTO @Detail
		SELECT
			bm.refno,
			bm.odds,
			bm.stake,
			bm.status,
			bm.bettype,
			bm.betteam
		FROM dbo.bettransm AS bm WITH (NOLOCK)
			INNER JOIN #PagingData AS b ON bm.refno = b.RefNo AND bm.custid = b.CustId
			INNER JOIN dbo.SportBettypeMatrix AS sbt WITH (NOLOCK) ON bm.bettype = sbt.Bettype
		WHERE b.Product = 'VR'
			AND sbt.ProductID = 5
			AND sbt.EventType = 3
	END

	SELECT
		TransId,
		RefNo,
		CustId,
		Currency,
		SportType,
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
		SettlementStatus,
		SecAcceptFlag,
		CheckTime,
		TransDate,
		WinLostDate,
		LiveIndicator,
		LiveHomeScore,
		LiveAwayScore,
		Ip,
		BetFrom,
		LeagueId,
		MatchId,
		MatchCode,
		Race,
		EventDate,
		HomeId,
		AwayId,
		BetStatus,
		IsNeutral,
		Placing,
		ShowTime,
		BetCheck,
		ComStatus,
		TransDesc,
		BetdaqId,
		ExtraInfo,
		OriginalStake,
		OriginalBetType,
		WalletType,
		RefCode
	FROM #PagingData
	ORDER BY RowNum ASC

	SELECT DISTINCT * FROM @Detail

	DROP TABLE #Data
	DROP TABLE #PagingData
END
GO
