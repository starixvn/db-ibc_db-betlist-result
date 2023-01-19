/*<info serverAlias="DBSID-bodb02" executers="bodbLicenseeNet" viewers="" isFunction="0" isNested="0"></info>*/

ALTER PROCEDURE [dbo].[SiteDB_Lrf_BetList_CustomerWL_Mem]
	@AgentList			VARCHAR(MAX),
	@CustId				INT,
	@FromDate			SMALLDATETIME,
	@ToDate				SMALLDATETIME,
	@MoveBetsDay		SMALLDATETIME,
	@BalanceUpDay		SMALLDATETIME,
	@BaseCurrency		VARCHAR(12),
	@PageSize			INT				= 1000,
	@PageIndex			INT				= 1,
	@TotalRows			INT				= 0 OUTPUT,
	@SumWinLost			MONEY			= 0 OUTPUT,
	@SumBetEffective	MONEY			= 0 OUTPUT,
	@SumLicenseeWL		MONEY			= 0 OUTPUT,
	@SumComm			MONEY			= 0 OUTPUT,
	@SumPlayerComm		MONEY			= 0 OUTPUT,
	@ShowSB				BIT				= 0,
	@ShowNG				BIT				= 0,
	@ShowBA				BIT				= 0,
	@ShowVS				BIT				= 0,
	@ShowCS				BIT				= 0,	-- RNG Casino
	@ShowKN				BIT				= 0,	-- Keno
	@ShowAGC			BIT				= 0,	-- AG Casino Single Wallet
	@ShowAB				BIT				= 0,	-- AllBet
	@ShowVB				BIT				= 0,	-- Voidbridge
	@ShowFW				BIT				= 0,	-- Fishing World
	@ShowVS2			BIT				= 0,	-- Betradar Virtual Sports
	@ShowLT				BIT				= 0,	-- Lottery
	@ShowPP				BIT				= 0,	-- Pragmatic Casino
	@ShowBT				BIT				= 0,	-- Bet Trade
	@ShowCO				BIT				= 0,	-- Cash Out
	@ShowCC				BIT				= 0,	-- Card Club
	@ShowSG				BIT				= 0,	-- Spadegaming
	@ShowVRG			BIT				= 0,	-- Virtual Games
	@ShowSAG			BIT				= 0,	-- SA Gaming
	@ShowTG				BIT				= 0,	-- Table Games
	@ShowSBC			BIT				= 0,	-- Saba.club
	@ShowI4D			BIT				= 0,	-- Indo 4D
	@ShowSXG			BIT				= 0,	-- Sexy Gaming
	@ShowPGS			BIT				= 0,	-- PG Soft
	@ShowJK				BIT				= 0,	-- Joker
	@ShowGDG			BIT				= 0,	-- GDG
	@ShowSLT			BIT				= 0,	-- Sports Lottery
	@ShowHB				BIT				= 0,	-- Habanero
	@ShowWM				BIT				= 0,	-- WM Live Casino
	@ShowBGG			BIT				= 0,	-- Big Gaming
	@ShowVGA			BIT				= 0,	-- Vgaming
	@ShowCG				BIT				= 0,	-- CG
	@ShowAP				BIT				= 0,	-- AdvantPlay
	@ShowAPM			BIT				= 0,	-- AdvantPlay Mini
	@ShowVS3			BIT				= 0,	-- Virtual Sports 3
	@ShowBTC			BIT				= 0,	-- BTC
	@ShowFGGL			BIT				= 0,	-- FGG
	@ShowMXG			BIT				= 0,	-- MaxGame
	@ShowJIG			BIT				= 0		-- Jili
AS

/*
	Created: 20220727@Kos
	Task: LAP - Bet List of Customer WL report - SiteDB
	DB: DBSID.bodb02

	Revisions:
		- 20220727@Kos: Scale out DBTRANS [Redmine: #175297]
		- 20220922@Kos: Support crypto currency [Redmine: 177481]
		- 20230119@Kos: Support Jili [Redmine: 182914]
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

	-- Get Sport Bettype Matrix
	DECLARE @SportBettype TABLE(ProductID TINYINT, BetType SMALLINT, EventType TINYINT, RefTable TINYINT)

	DECLARE @IsTest BIT = 0

	SELECT @IsTest = dbo.f_CheckSPVersion(@@PROCID)

	INSERT INTO @SportBettype
	SELECT ProductID, BetType, EventType, RefTable
	FROM dbo.f_SportBettypeMatrix_Sel (0, 0, 0, 2, '', '', @IsTest)
	WHERE (ProductID	= CASE WHEN @ShowSB = 1 OR @ShowBA = 1 THEN 1 END AND Bettype NOT IN (901, 902, 903))
		OR ProductID	= CASE WHEN @ShowNG = 1		THEN 3 END
		OR ProductID	= CASE WHEN @ShowVS = 1		THEN 5 END
		OR ProductID	= CASE WHEN @ShowCS = 1		THEN 6 END
		OR ProductID	= CASE WHEN @ShowKN = 1		THEN 8 END
		OR ProductID	= CASE WHEN @ShowAGC = 1	THEN 11 END
		OR ProductID	= CASE WHEN @ShowAB = 1		THEN 21 END
		OR ProductID	= CASE WHEN @ShowVB = 1		THEN 22 END
		OR ProductID	= CASE WHEN @ShowFW = 1		THEN 24 END
		OR ProductID	= CASE WHEN @ShowCO = 1		THEN 25 END
		OR ProductID	= CASE WHEN @ShowVS2 = 1	THEN 27 END
		OR ProductID	= CASE WHEN @ShowLT = 1		THEN 28 END
		OR ProductID	= CASE WHEN @ShowPP = 1		THEN 32 END
		OR ProductID	= CASE WHEN @ShowCC = 1		THEN 34 END
		OR ProductID	= CASE WHEN @ShowSG = 1		THEN 36 END
		OR ProductID	= CASE WHEN @ShowVRG = 1	THEN 38 END
		OR ProductID	= CASE WHEN @ShowSAG = 1	THEN 39 END
		OR ProductID	= CASE WHEN @ShowTG = 1		THEN 40 END
		OR ProductID	= CASE WHEN @ShowSBC = 1	THEN 42 END
		OR ProductID	= CASE WHEN @ShowI4D = 1	THEN 43 END
		OR ProductID	= CASE WHEN @ShowSXG = 1	THEN 45 END
		OR ProductID	= CASE WHEN @ShowVS3 = 1	THEN 49 END
		OR ProductID	= CASE WHEN @ShowWM = 1		THEN 51 END
		OR ProductID	= CASE WHEN @ShowPGS = 1	THEN 55 END
		OR ProductID	= CASE WHEN @ShowJK = 1		THEN 56 END
		OR ProductID	= CASE WHEN @ShowBGG = 1	THEN 57 END
		OR ProductID	= CASE WHEN @ShowGDG = 1	THEN 59 END
		OR ProductID	= CASE WHEN @ShowMXG = 1	THEN 60 END
		OR ProductID	= CASE WHEN @ShowHB = 1		THEN 61 END
		OR ProductID	= CASE WHEN @ShowCG = 1		THEN 62 END
		OR ProductID	= CASE WHEN @ShowSLT = 1	THEN 63 END
		OR ProductID	= CASE WHEN @ShowVGA = 1	THEN 66 END
		OR ProductID	= CASE WHEN @ShowAP = 1		THEN 67 END
		OR ProductID	= CASE WHEN @ShowAPM = 1	THEN 68 END
		OR ProductID	= CASE WHEN @ShowBTC = 1	THEN 69 END
		OR ProductID	= CASE WHEN @ShowFGGL = 1	THEN 70 END
		OR ProductID	= CASE WHEN @ShowJIG = 1	THEN 75 END

	DELETE @SportBettype
	WHERE BetType IN (71, 73, 904, 914)
		OR BetType BETWEEN 801 AND 899
		OR BetType IN (SELECT BetType FROM dbo.Lrf_f_SelExcludedBetType())

	IF @ShowBT = 0
	BEGIN
		DELETE @SportBettype
		WHERE ProductID = 1 AND BetType IN (901, 902, 903)
	END

	CREATE TABLE #Data (
		TransId				BIGINT,
		RefNo				BIGINT,
		BATransId			BIGINT,
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
		AWinLost			MONEY,
		WinLost				MONEY,
		BetEffective		MONEY,
		LicenseeWL			MONEY,
		PlayerComm			MONEY,
		Comm				MONEY,
		Status				NVARCHAR(10),
		SettlementStatus	TINYINT,
		TransDate			DATETIME,
		WinLostDate			SMALLDATETIME,
		LiveIndicator		BIT,
		LiveHomeScore		SMALLINT,
		LiveAwayScore		SMALLINT,
		Ip					VARCHAR(45),
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
		SiteId				VARCHAR(20),
		TableID				TINYINT,
		Product				VARCHAR(30),
		RefTable			TINYINT
	)

	CREATE TABLE #PagingData (
		RowNum				INT,
		TransId				BIGINT,
		RefNo				BIGINT,
		BATransId			BIGINT,
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
		AWinLost			MONEY,
		WinLost				MONEY,
		BetEffective		MONEY,
		LicenseeWL			MONEY,
		PlayerComm			MONEY,
		Comm				MONEY,
		Status				NVARCHAR(10),
		SettlementStatus	TINYINT,
		TransDate			DATETIME,
		WinLostDate			SMALLDATETIME,
		LiveIndicator		BIT,
		LiveHomeScore		SMALLINT,
		LiveAwayScore		SMALLINT,
		Ip					VARCHAR(45),
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
		SiteId				VARCHAR(20),
		TableID				TINYINT,
		Product				VARCHAR(30),
		RefTable			TINYINT
	)

	DECLARE @Detail TABLE (
		RefNo			BIGINT,
		Odds			MONEY,
		Stake			MONEY,
		Status			NVARCHAR(10),
		APositionTaking	SMALLMONEY,
		BetType			SMALLINT,
		BetTeam			NVARCHAR(10)
	)

	DECLARE @TmpData TABLE (
		RefNo			BIGINT,
		Odds			MONEY,
		Stake			MONEY,
		Actual_Stake	MONEY,
		Status			NVARCHAR(10),
		WinLost			MONEY,
		BetEffective	MONEY,
		LicenseeWL		MONEY,
		PlayerComm		MONEY,
		Comm			MONEY,
		OddsSpread		MONEY
	)

	CREATE TABLE #ExchangeRate (
		FirstExchangeDateByMonth	SMALLDATETIME,
		LastExchangeDateByMonth		SMALLDATETIME,
		Rate						FLOAT
	)

	DECLARE @Yesterday SMALLDATETIME = DATEADD(DAY, DATEDIFF(DAY, 1, CURRENT_TIMESTAMP), 0)

	DECLARE @Currency	INT,
		@Nickname		NVARCHAR(50)

	IF @HasError = 0
	BEGIN
		DECLARE @TempToDate	SMALLDATETIME,
			@TempFromDate	SMALLDATETIME

		-- bettrans
		IF @ToDate > @MoveBetsDay
		BEGIN
			IF @FromDate <= @MoveBetsDay
				SET @TempFromDate = DATEADD(DAY, 1, @MoveBetsDay)
			ELSE
				SET @TempFromDate = @FromDate

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
				AWinLost,
				WinLost,
				PlayerComm,
				Comm,
				Status,
				TransDate,
				WinLostDate,
				LiveIndicator,
				LiveHomeScore,
				LiveAwayScore,
				Ip,
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
				ISNULL(b.BetId, 0) AS BetId,
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
				b.awinlost,
				b.winlost,
				b.playercomm,
				b.comm,
				b.status,
				b.transdate,
				b.winlostdate,
				b.liveindicator,
				b.livehomescore,
				b.liveawayscore,
				b.ip,
				b.matchid,
				b.betcheck,
				b.comstatus,
				b.transdesc,
				b.betdaqid,
				b.ExtraInfo,
				b.WalletType,
				ISNULL(b.RefCode, 0),
				1 AS TableID
			FROM dbo.bettrans AS b WITH (NOLOCK, INDEX = IX_custid)
				INNER JOIN @SportBettype AS s ON s.Bettype = b.bettype
			WHERE b.custid = @CustId
				AND b.winlostdate BETWEEN @TempFromDate AND @ToDate
				AND (b.statusID IN (111, 112, 113)
					OR (b.winlostdate >= @Yesterday AND s.RefTable IN (1, 2)))	-- don't care status of casino's summary rows if >= yesterday
		END

		DELETE b
		FROM #Data AS b
		WHERE NOT EXISTS (SELECT 1 FROM @TempAg WHERE CustId = b.Recommend AND Currency = b.Currency)

		IF EXISTS (SELECT TOP(1) 1 FROM #Data)
		BEGIN
			-- Get Sport/Bettype info
			UPDATE b
			SET
				BATransId = ba.TransID,
				Product = CASE
							WHEN s.ProductID = 6 THEN 'OneRNG'							-- RNG Casino
							WHEN s.ProductID = 8 THEN 'Keno'
							WHEN s.ProductID = 21 THEN 'AllBet'
							WHEN s.ProductID = 22 THEN 'VB'								-- Macau Games
							WHEN s.ProductID = 24 THEN 'FW'								-- Fishing World
							WHEN s.ProductID = 25 THEN 'CO'								-- Cash Out
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
							WHEN s.ProductID = 49 THEN 'VS3'							-- Virtual Sports 3
							WHEN s.ProductID = 51 THEN 'WM'								-- WM Live Casino
							WHEN s.ProductID = 55 THEN 'PGS'							-- PG Soft
							WHEN s.ProductID = 56 THEN 'JK'								-- Joker
							WHEN s.ProductID = 57 THEN 'BG'								-- Big Gaming
							WHEN s.ProductID = 59 THEN 'GDG'							-- GDG
							WHEN s.ProductID = 60 THEN 'MXG'							-- MaxGame
							WHEN s.ProductID = 61 THEN 'HB'								-- Habanero
							WHEN s.ProductID = 62 THEN 'CG'								-- CG
							WHEN s.ProductID = 63 THEN 'SLT'							-- Sports Lottery
							WHEN s.ProductID = 66 THEN 'VGA'							-- Vgaming
							WHEN s.ProductID = 67 THEN 'AP'								-- AdvantPlay
							WHEN s.ProductID = 68 THEN 'APM'							-- AdvantPlay Mini
							WHEN s.ProductID = 69 THEN 'BTC'							-- Bitcoin
							WHEN s.ProductID = 70 THEN 'FGGL'							-- FGG
							WHEN s.ProductID = 75 THEN 'JIG'							-- Jili
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
				INNER JOIN @SportBettype AS s ON b.bettype = s.bettype
				LEFT JOIN dbo.LicenseeBATransaction_active AS ba WITH (NOLOCK) ON b.transid = ba.TransID AND b.TableID = 1

			DELETE #Data
			WHERE Product = 'Unknown'
				OR Product IS NULL
				OR BetType IN (901, 902, 903, 904, 914)
				OR BetType BETWEEN 801 AND 899
				OR (@ShowSB = 0
					AND Product IN ('SB', 'Parlay', 'Outright')
					AND BATransId IS NULL)
				OR (@ShowBA = 0
					AND Product IN ('SB', 'Parlay', 'Outright')
					AND BATransId IS NOT NULL)

			UPDATE #Data
			SET
				WinLost = WinLost - Actual_Stake,
				BetEffective = ABS(WinLost - Actual_Stake),
				LicenseeWL = CASE
								WHEN BATransId IS NOT NULL THEN 0
								ELSE - (WinLost - Actual_Stake)
							END

			-- Get data for summary ticket of multiple Bonus/Cash sub tickets
			IF EXISTS (SELECT 1 FROM #Data WHERE RefCode <> 0)
			BEGIN
				DECLARE @RefCodeTmp TABLE (
					RefCode			BIGINT,
					TransId			BIGINT,
					Stake			MONEY,
					Actual_Stake	MONEY,
					WinLost			MONEY,
					BetEffective	MONEY,
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
					SUM(BetEffective) AS BetEffective,
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
						b.BetEffective = r.BetEffective,
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

			-- Get yesterday and today settled bettransRnG/bettransLC tickets
			IF EXISTS (SELECT 1 FROM #Data WHERE RefTable = 1 AND WinLostDate >= @Yesterday)		-- bettransRnG
			BEGIN
				INSERT INTO @TmpData
				SELECT
					c.TransId AS RefNo,
					CASE
						WHEN Product = 'OneRNG' THEN ISNULL(AVG(CASE WHEN brng.statusID IN (111, 112, 113) THEN brng.ContributionRate END), 0)
						ELSE 0
					END AS Odds,
					SUM(brng.stake) AS Stake,
					SUM(brng.actual_stake) AS Actual_Stake,
					CASE
						WHEN SUM(brng.winlost - brng.actual_stake) > 0 THEN 'Won'
						WHEN SUM(brng.winlost - brng.actual_stake) < 0 THEN 'Lose'
						ELSE 'Draw'
					END AS Status,
					SUM(brng.winlost - brng.actual_stake) AS WinLost,
					ABS(SUM(brng.winlost - brng.actual_stake)) AS BetEffective,
					- SUM(brng.winlost - brng.actual_stake) AS LicenseeWL,
					SUM(brng.playercomm) AS Commission,
					SUM(brng.comm) AS Comm,
					CASE
						WHEN c.Product IN ('OneRNG') THEN SUM(ISNULL(brng.BetStake, 0))
						ELSE 0
					END AS OddsSpread
				FROM #Data AS c
					INNER JOIN dbo.bettransRnG AS brng WITH (NOLOCK) ON brng.RefNo = c.TransId
				WHERE c.RefTable = 1
					AND c.WinLostDate >= @Yesterday
					AND brng.statusID NOT IN (0, 1)
				GROUP BY
					c.TransId,
					c.Product
			END

			IF EXISTS (SELECT 1 FROM #Data WHERE RefTable = 2 AND WinLostDate >= @Yesterday)				-- bettransLC
			BEGIN
				INSERT INTO @TmpData
				SELECT
					c.TransId AS RefNo,
					0 AS Odds,
					SUM(blc.stake) AS Stake,
					SUM(blc.actual_stake) AS Actual_Stake,
					CASE
						WHEN SUM(blc.winlost - blc.actual_stake) > 0 THEN 'Won'
						WHEN SUM(blc.winlost - blc.actual_stake) < 0 THEN 'Lose'
						ELSE 'Draw'
					END AS Status,
					SUM(blc.winlost - blc.actual_stake) AS WinLost,
					ABS(SUM(blc.winlost - blc.actual_stake)) AS BetEffective,
					- SUM(blc.winlost - blc.actual_stake) AS LicenseeWL,
					SUM(blc.playercomm) AS Commission,
					SUM(blc.comm) AS Comm,
					0 AS OddsSpread
				FROM #Data AS c
					INNER JOIN dbo.bettransLC AS blc WITH (NOLOCK) ON blc.RefNo = c.TransId
				WHERE c.RefTable = 2
					AND c.WinLostDate >= @Yesterday
					AND blc.statusID NOT IN (0, 1)
				GROUP BY
					c.TransId,
					c.Product
			END

			DELETE b
			FROM #Data AS b
			WHERE b.RefTable IN (1, 2)
				AND b.Winlostdate >= @Yesterday
				AND NOT EXISTS (SELECT 1 FROM @TmpData WHERE RefNo = b.TransId)

			-- Exclude Saba.club Freebet tickets
			DELETE FROM #Data
			WHERE Product = 'SBC' AND MatchId = 150

			-- Exclude Vgaming Freebet tickets
			DELETE FROM #Data
			WHERE Product = 'VGA' AND MatchId = 173

			DECLARE @Username VARCHAR(50)

			SELECT @Currency = currency,
				@Username = username,
				@Nickname = SUBSTRING(username2, CHARINDEX('$', username2) + 1, LEN(username2) - CHARINDEX('$', username2))
			FROM CustDB.dbo.Customer WITH (NOLOCK)
			WHERE custid = @CustId

			DECLARE @ExFromDate SMALLDATETIME,
				@ExToDate SMALLDATETIME

			SELECT
				@ExFromDate = MIN(WinLostDate),
				@ExToDate = MAX(WinLostDate)
			FROM #Data

			-- Get exchange rate
			IF @BaseCurrency <> ''
			BEGIN
				INSERT INTO #ExchangeRate
				SELECT
					e.FromDate,
					e.ToDate,
					e.Rate
				FROM dbo.SiteDB_Lrf_f_GetExchangeRate(@ExFromDate, @ExToDate, @BaseCurrency, '') AS e
				WHERE e.ExchangeId = @Currency
					AND EXISTS (SELECT 1 FROM #Data WHERE WinLostDate BETWEEN e.FromDate AND e.ToDate)
			END

			-- Return data
			SELECT
				@TotalRows		= COUNT(b.TransId),
				@SumWinlost		= SUM(CASE
										WHEN b.RefTable IN (1, 2) AND x.WinLost IS NOT NULL THEN x.WinLost
										ELSE b.WinLost
									END * ISNULL(e.Rate, 1)),
				@SumBetEffective	= SUM(CASE
										WHEN b.RefTable IN (1, 2) AND x.BetEffective IS NOT NULL THEN x.BetEffective
										ELSE b.BetEffective
									END * ISNULL(e.Rate, 1)),
				@SumLicenseeWL	= SUM(CASE
										WHEN b.RefTable IN (1, 2) AND x.LicenseeWL IS NOT NULL THEN x.LicenseeWL
										ELSE b.LicenseeWL
									END * ISNULL(e.Rate, 1)),
				@SumComm		= SUM(CASE
										WHEN b.RefTable IN (1, 2) AND x.Comm IS NOT NULL THEN x.Comm
										ELSE b.Comm
									END * ISNULL(e.Rate, 1)),
				@SumPlayerComm	= SUM(CASE
										WHEN b.RefTable IN (1, 2) AND x.PlayerComm IS NOT NULL THEN x.PlayerComm
										ELSE b.PlayerComm
									END * ISNULL(e.Rate, 1))
			FROM #Data AS b
				LEFT JOIN @TmpData AS x
					ON b.RefTable IN (1, 2)
					AND b.WinLostDate >= @Yesterday
					AND x.RefNo = b.transid
				LEFT JOIN #ExchangeRate AS e ON b.WinLostDate BETWEEN e.FirstExchangeDateByMonth AND e.LastExchangeDateByMonth

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
							ROW_NUMBER() OVER (ORDER BY TransDate ASC) AS RowNum,
							*
						FROM #Data
					) AS a
				WHERE a.RowNum BETWEEN @RowStart AND @RowEnd
				ORDER BY a.RowNum'

			INSERT INTO #PagingData
			EXEC sp_executesql @Sql, N'@RowStart INT, @RowEnd INT', @RowStart, @RowEnd;

			DROP TABLE #Data

			-- bettrans
			IF EXISTS (SELECT TOP(1) 1 FROM #PagingData WHERE TableID = 1)
			BEGIN
				UPDATE b
				SET
					TransId = CASE
								WHEN b.Product = 'Parlay' AND b.BetType = 29 AND ISNULL(b.BetId, 0) > 0 THEN b.BetId
								ELSE b.TransId
							END,
					SportType = CASE
									WHEN b.Product IN ('Keno', 'Lottery', 'OneRNG', 'CC', 'SG', 'VRG', 'TG', 'SBC', 'I4D', 'SXG', 'SAG', 'PGS', 'JK', 
										'H5LG', 'GDG', 'SLT', 'HB', 'WM', 'BG', 'VGA', 'CG', 'AP', 'APM', 'VS3', 'FGGL', 'MXG', 'JIG') THEN b.MatchId
									WHEN b.Product = 'AllBet' THEN 211		-- AllBet
									WHEN b.Product = 'VB' THEN 212			-- Macau Games
									WHEN b.Product = 'FW' THEN 219			-- Fishing World
									WHEN b.Product = 'PP' THEN 248			-- Pragmatic Casino
									WHEN b.Product IN ('SB', 'CO', 'NG', 'VS', 'VS2') THEN m.sporttype
									WHEN b.Product IN ('BTC') THEN m3rd.sporttype
									WHEN b.Product IN ('Outright') THEN l.sporttype
									WHEN b.Product IN ('VR') THEN vr.SportType
									ELSE 0
								END,
					BetTeam = CASE
									WHEN b.Product IN ('SB', 'CO', 'NG', 'VS', 'VS2', 'Parlay', 'ParlayVS2', 'BTC') THEN b.BetTeam
									ELSE ''
								END,
					Hdp1 = CASE
								WHEN b.Product IN ('SB', 'CO', 'NG', 'VS', 'VS2', 'VR', 'Parlay', 'ParlayVS2', 'BTC') THEN b.Hdp1
								ELSE 0
							END,
					Hdp2 = CASE
								WHEN b.Product IN ('SB', 'CO', 'VS', 'VS2', 'VR', 'Parlay', 'ParlayVS2') THEN b.Hdp2
								ELSE 0
							END,
					OddsType = CASE
								WHEN b.Product IN ('SB', 'CO', 'NG', 'VS', 'VS2', 'Outright') THEN b.OddsType
								ELSE 0
							END,
					Odds = CASE
								WHEN b.Product IN ('VB', 'FW', 'PP', 'OneRNG', 'Allbet') AND x.Odds IS NOT NULL THEN x.Odds
								WHEN b.Product IN ('SB', 'CO', 'NG', 'VS', 'VS2', 'Outright', 'VR', 'Parlay', 'ParlayVS2', 'Keno', 'Lottery', 
									'OneRNG', 'VRG', 'TG', 'I4D', 'SLT', 'H5LG', 'VS3', 'BTC') THEN b.Odds
								ELSE 0
							END,
					MOdds = CASE 
								WHEN b.Product IN ('SB', 'CO', 'NG', 'VS', 'VS2', 'Outright', 'VR', 'Parlay', 'ParlayVS2')  THEN b.modds
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
								WHEN b.RefTable IN (1, 2) AND x.Status IS NOT NULL THEN x.Status
								WHEN b.Product = 'TG' AND b.status = 'Won' AND b.modds = 0.25 THEN 'Half Won'
								WHEN b.Product = 'TG' AND b.status = 'Lose' AND b.modds = -0.25 THEN 'Half Lose'
								ELSE b.status
							END,
					SettlementStatus = CASE
										WHEN b.Product = 'SB' THEN ISNULL(m.SettlementStatus, 0)
										ELSE 0
									END,
					WinLost = CASE
									WHEN b.RefTable IN (1, 2) AND x.WinLost IS NOT NULL THEN x.WinLost
									ELSE b.WinLost
								END,
					BetEffective = CASE
									WHEN b.RefTable IN (1, 2) AND x.BetEffective IS NOT NULL THEN x.BetEffective
									ELSE b.BetEffective
								END,
					LicenseeWL = CASE
									WHEN b.RefTable IN (1, 2) AND x.LicenseeWL IS NOT NULL THEN x.LicenseeWL
									ELSE b.LicenseeWL
								END,
					PlayerComm = CASE
									WHEN b.RefTable IN (1, 2) AND x.PlayerComm IS NOT NULL THEN x.PlayerComm
									ELSE b.PlayerComm
								END,
					Comm = CASE
									WHEN b.RefTable IN (1, 2) AND x.Comm IS NOT NULL THEN x.Comm
									ELSE b.Comm
								END,
					LiveIndicator = CASE
										WHEN b.Product IN ('SB', 'CO', 'NG', 'VS', 'VS2') THEN b.liveindicator
										ELSE 0
									END,
					LiveHomeScore = CASE
										WHEN b.Product IN ('SB', 'CO', 'NG', 'VS', 'VS2', 'Outright', 'VR', 'Parlay') THEN b.livehomescore
										ELSE 0
									END,
					LiveAwayScore = CASE
										WHEN b.Product IN ('SB', 'CO', 'NG', 'VS', 'VS2', 'Outright', 'VR') THEN b.liveawayscore
										ELSE 0
									END,
					LeagueId = CASE
									WHEN b.Product IN ('SB', 'CO', 'NG', 'VS', 'VS2') THEN m.leagueid
									WHEN b.Product IN ('Outright') THEN o.leagueid
									WHEN b.Product IN ('VR') THEN vr.LeagueID
									ELSE 0
								END,
					MatchId = CASE
									WHEN b.Product IN ('SB', 'CO', 'NG', 'VS', 'VS2', 'VR', 'BTC') THEN b.matchid
									ELSE 0
								END,
					MatchCode = CASE
									WHEN b.Product IN ('SB', 'CO', 'NG', 'VS', 'VS2') THEN m.matchcode
									WHEN b.Product IN ('VR') THEN CONVERT(NVARCHAR(50), vo.RacerNum)
									ELSE ''
								END,
					Race = CASE
								WHEN b.Product IN ('VR') THEN CONVERT(NVARCHAR(50), b.oddsid)
								ELSE ''
							END,
					EventDate = CASE
									WHEN b.Product IN ('SB', 'CO') THEN m.GlobalShowTime
									WHEN b.Product IN ('BTC') THEN m3rd.EndTime
								ELSE b.WinLostDate
							END,
					HomeId = CASE
								WHEN b.Product IN ('SB', 'CO', 'NG', 'VS', 'VS2') THEN m.homeid
								WHEN b.Product IN ('Outright') THEN o.teamid
								WHEN b.Product IN ('VR') THEN vo.RacerID
								ELSE 0
							END,
					AwayId = CASE
								WHEN b.Product IN ('SB', 'CO', 'NG', 'VS', 'VS2') THEN m.awayid
								ELSE 0
							END,
					BetStatus = CASE
									WHEN b.Product IN ('SB', 'CO', 'NG', 'VS', 'VS2') THEN m.betstatus
									ELSE ''
								END,
					IsNeutral = CASE
									WHEN b.Product IN ('SB', 'CO', 'NG', 'VS', 'VS2') THEN ISNULL(m.IsNeutral, 0)
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
									WHEN b.Product IN ('SB', 'CO', 'Parlay', 'ParlayVS2', 'VRG', 'H5LG', 'SLT') THEN ISNULL(b.betcheck, '')
									WHEN b.Product IN ('Keno') THEN ISNULL(b.ComStatus, '')
									ELSE ''
								END,
					TransDesc = CASE
									WHEN b.Product IN ('SB', 'CO', 'VS2', 'Keno', 'Lottery', 'OneRNG', 'CC', 'SG', 'VB', 'FW', 'PP', 
										'VRG', 'TG', 'I4D', 'PGS', 'JK', 'H5LG', 'SLT', 'HB', 'CG', 'AP', 'APM', 'VS3') THEN ISNULL(b.transdesc, '')
									ELSE ''
								END,
					OddsSpread = CASE
									WHEN b.Product IN ('SB', 'CO') THEN ISNULL(b.oddsspread, 0)
									ELSE 0
								END,
					BetdaqId = CASE
									WHEN b.Product IN ('SB', 'CO') THEN ISNULL(b.betdaqid, -1)
									ELSE -1
								END,
					ExtraInfo = CASE
									WHEN b.Product IN ('SB', 'Parlay', 'Outright', 'Keno', 'Lottery', 'TG', 'SLT', 'NG', 'H5LG', 'VS', 'VS2', 
										'ParlayVS2', 'VR', 'VS3', 'BTC') THEN ISNULL(b.ExtraInfo, '')
									ELSE ''
								END,
					OriginalStake = CASE
										WHEN b.Product IN ('SB') AND b.ExtraInfo LIKE '%p25%' THEN
											ISNULL(CAST(('<xml>' + b.ExtraInfo + '</xml>') AS XML).value('data(/xml/p25/@s)[1]','MONEY'), 0)
										ELSE 0
									END,
					OriginalBetType = CASE
										WHEN b.Product IN ('SB') AND b.stake <> 0 THEN -1
										WHEN b.Product IN ('CO') THEN b.OriginalBetType
										ELSE 0
									END,
					WalletType = CASE
									WHEN b.Product IN ('SB') THEN ISNULL(b.WalletType, 0)
									ELSE 0
								END,
					RefCode = CASE
									WHEN b.Product IN ('SB') AND b.stake <> 0 THEN ISNULL(b.RefCode, 0)
									ELSE 0
								END,
					SiteId = CASE
								WHEN b.Product IN ('H5LG', 'SLT', 'VRG') THEN CONVERT(VARCHAR(20), b.BetdaqId)
								ELSE ''
							END
				FROM #PagingData AS b
					LEFT JOIN @TmpData AS x
						ON b.RefTable IN (1, 2)
						AND b.Winlostdate >= @Yesterday
						AND x.RefNo = b.transid
					LEFT JOIN dbo.match AS m WITH (NOLOCK) ON b.Product IN ('SB', 'CO', 'NG', 'VS', 'VS2') AND b.matchid = m.matchid
					LEFT JOIN dbo.Match3rd AS m3rd WITH (NOLOCK) ON b.Product IN ('BTC') AND b.matchid = m3rd.Match3rdId
					LEFT JOIN dbo.outright AS o WITH (NOLOCK) ON b.Product IN ('Outright') AND b.matchid = o.orid
					LEFT JOIN dbo.League AS l WITH (NOLOCK) ON b.Product IN ('Outright') AND o.leagueID = l.leagueID
					LEFT JOIN dbo.VSOutright AS vo WITH (NOLOCK) ON b.Product IN ('VR') AND b.oddsid = vo.Orid
					LEFT JOIN dbo.VSRaceInfo AS vr WITH (NOLOCK) ON b.Product IN ('VR') AND vr.EventID = vo.EventID
				WHERE b.TableID = 1
			END
		END
	END

	-- Get ticket detail
	-- Virtual Sports
	IF EXISTS (SELECT 1 FROM #PagingData WHERE Product = 'VR' AND TableID = 1)
	BEGIN
		INSERT INTO @Detail
		SELECT
			bm.refno,
			bm.odds,
			bm.stake * ISNULL(e.Rate, 1) AS Stake,
			bm.status,
			bm.apositiontaking,
			bm.bettype,
			bm.betteam
		FROM dbo.bettransm AS bm WITH (NOLOCK)
			INNER JOIN #PagingData AS b ON bm.refno = b.RefNo AND bm.custid = b.CustId
			INNER JOIN dbo.SportBettypeMatrix AS sbt WITH (NOLOCK) ON bm.bettype = sbt.Bettype
			LEFT JOIN #ExchangeRate AS e ON bm.WinLostDate BETWEEN e.FirstExchangeDateByMonth AND e.LastExchangeDateByMonth
		WHERE b.Product = 'VR'
			AND b.TableID = 1
			AND sbt.ProductID = 5
			AND sbt.EventType = 3
	END

	-- Return data
	SELECT
		@Username AS Username,
		@Nickname AS NickName,
		a.TransId,
		a.RefNo,
		a.BetId,
		a.CustId,
		a.TransDate,
		a.WinLostDate,
		a.SportType,
		a.BetType,
		a.BetTeam,
		a.Hdp1,
		a.Hdp2,
		a.Odds,
		a.MOdds,
		a.OddsType,
		a.OddsSpread,
		a.Status,
		a.SettlementStatus,
		a.LiveIndicator,
		a.LiveHomeScore,
		a.LiveAwayScore,
		a.Race,
		a.LeagueId,
		a.MatchId,
		a.MatchCode,
		a.EventDate,
		a.HomeId,
		a.AwayId,
		a.IsNeutral,
		a.BetStatus,
		a.Placing,
		a.ShowTime,
		a.Currency,
		a.Stake * ISNULL(e.Rate, 1) AS Stake,
		a.Actual_Stake * ISNULL(e.Rate, 1) AS Actual_Stake,
		a.WinLost * ISNULL(e.Rate, 1) AS WinLost,
		a.BetEffective * ISNULL(e.Rate, 1) AS BetEffective,
		a.LicenseeWL * ISNULL(e.Rate, 1) AS LicenseeWL,
		a.Comm * ISNULL(e.Rate, 1) AS Comm,
		a.PlayerComm * ISNULL(e.Rate, 1) AS PlayerComm,
		a.Ip,
		a.BetCheck,
		a.TransDesc,
		a.BetdaqId,
		a.ExtraInfo,
		a.OriginalStake * ISNULL(e.Rate, 1) AS OriginalStake,
		a.OriginalBetType,
		a.WalletType,
		a.RefCode,
		a.SiteId
	FROM
		#PagingData AS a
		LEFT JOIN #ExchangeRate AS e ON a.WinLostDate BETWEEN e.FirstExchangeDateByMonth AND e.LastExchangeDateByMonth
	ORDER BY a.RowNum ASC

	SELECT DISTINCT * FROM @Detail

	DROP TABLE #PagingData
	DROP TABLE #ExchangeRate
END
GO
