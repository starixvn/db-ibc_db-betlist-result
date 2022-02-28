/*<info serverAlias="DBBOF-bodb02" executers="bodbLicenseeNet" viewers="" isFunction="0" isNested="0"></info>*/

ALTER PROCEDURE [dbo].[Lrf_BetList_Running]
	@AgentList			VARCHAR(MAX),
	@CustId				INT				= 0,
	@Username			VARCHAR(50)		= '',
	@BaseCurrency		VARCHAR(10),
	@ConvertToBaseCur	BIT				= 0,	-- Convert to base currency or not
	@StatusFilter		VARCHAR(10)		= '1,2,3',
	@PageSize			INT				= 1000,
	@PageIndex			INT				= 1,
	@Sort				NVARCHAR(50)	= N'TransDate DESC',
	@ProductList		VARCHAR(200)	= '',
	@ShowBA				BIT				= 0,	-- BA
	@TotalRows			INT				= 0 OUTPUT,
	@SumStake			MONEY			= 0 OUTPUT
AS

/*
	Created: Kos@20180613
	Task: Betting Ticket Center - Running Bet List
	DB: DBBOF.bodb02
	Param's Explanation:
		- @StatusFilter:
			- 1: Running, Waiting
			- 2: Delay Payout
			- 3: Under Settlement

	Revisions:
		- 20180613@Kos: Created [#Redmine: 80941]
		- 20181114@Kos: Change getting ticket status [#Redmine: 104664]
		- 20181121@Kos: Support 2 new statuses Result Pending and Under Settlement [#Redmine: 102428]
		- 20190107@Kos: Support Parlay Changes [#Redmine: 107165]
		- 20190121@Kos: Betting Ticket Center phase 3a [Redmine: #103555]
					- Remove param @FromDate and @ToDate
		- 20190305@Kos: Add new param @StatusFilter, @ConvertToBaseCur [Redmine: #108717]
					- Remove param @CurrencyId
		- 20190411@Kos: Support search LIKE on username [Redmine: #111665]
		- 20190422@Kos: Enhance performance for searching too many members [Redmine: #112313]
		- 20190426@Kos: Support base currency INH [Redmine: #112603]
		- 20190506@Kos: Result Pending for SettlementStatus = 5 [Redmine: #112886]
		- 20190509@Kos: Show match KO time for single ticket [Redmine: #112731]
					- Return additional column EventDate DATETIME
		- 20190627@Kos: Support PH AIO 4a [Redmine: #115448]
		- 20190730@Kos: Support new status Pending [#Redmine: 117729]
		- 20191031@Kos: Show Running status for Marked tickets [Redmine: 120309]
		- 20200207@Kos: Support sort by trans time [Redmine: #126886]
		- 20200402@Kos: Support Table Games [Redmine: #131447]
		- 20200416@Kos: Support Indo 4D [Redmine: #130859]
		- 20200425@Kos: Support status Delay Payout [Redmine: #132629]
		- 20200525@Kos: Support show licensee transaction ID [Redmine: #134629]
		- 20201231@Kos: Support Virtual Games [Redmine: #147843]
		- 20200108@Kos: Support Happy 5 Linked Games [Redmine: #147446]
		- 20210301@Kos: Add BDT and INR as base currencies [Redmine: 150375]
		- 20210311@Kos: Support Sports Lottery [Redmine: #150872]
		- 20210705@Kos: Support Happy 5 Linked Games - Soccer 5 [Redmine: #154898]
		- 20210714@Kos: Support Casino products [Redmine: #157987]
		- 20210929@Kos: Extend length to support IPv6 [Redmine: 162342]
		- 20211102@Kos: Support AdvantPlay and AdvantPlay Mini [Redmine: #158186]
		- 20211215@Kos: Hotfix - Show Casino tickets when choosing Delayed Payout [Redmine: #166109]
		- 20220110@Kos: Support TxId for 3rd products [Redmine: #166706]
		- 20220227@Kos: Support Virtual Sports 3 [Redmine: #145337]
*/

BEGIN
	SET NOCOUNT ON

	DECLARE @HasError BIT = 0

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
		SET @HasError = 1
	END CATCH

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
		BetFrom				NVARCHAR(1),
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
		BetFrom				NVARCHAR(1),
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
		Odds			MONEY,
		OddsSpread		MONEY,
		Stake			MONEY,
		Actual_Stake	MONEY,
		IsNew			BIT
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

	-- Get exchange rate
	CREATE TABLE #ExchangeRate (
		ExchangeId	INT,
		Rate		FLOAT
	)

	IF @HasError = 0
	BEGIN
		DECLARE @TempCust TABLE (CustId INT)

		IF @Username IS NOT NULL AND @Username <> ''
		BEGIN
			INSERT INTO @TempCust
			SELECT c.custid
			FROM dbo.Customer AS c WITH (NOLOCK)
				INNER JOIN #TempAg AS a ON c.recommend = a.CustId
			WHERE c.roleid = 1
				AND (c.username LIKE + '%' + @Username + '%'
					OR c.username2 LIKE + '%$%' + @Username + '%')
		END

		DECLARE @NumOfMem	INT = 0

		SELECT @NumOfMem = COUNT(1) FROM @TempCust

		IF @Username IS NULL OR @Username = '' OR @NumOfMem > 5000		-- Licensee level (not input username of number of searched member > 5000)
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
			FROM dbo.bettrans AS b WITH (NOLOCK, INDEX = IX_betrunning_recommend)
				INNER JOIN #TempAg AS a ON a.CustId = b.recommend
			WHERE b.statusID IN (0, 1)

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
			FROM dbo.translog AS b WITH (NOLOCK, INDEX = IX_betrunning_recommend)
				INNER JOIN #TempAg AS a ON a.CustId = b.recommend
			WHERE b.statusID IN (0, 1)
		END
		ELSE		-- Customer level
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
			FROM dbo.bettrans AS b WITH (NOLOCK, INDEX = IX_betrunning_custid)
				INNER JOIN @TempCust AS c ON b.custid = c.CustId
			WHERE b.statusID IN (0, 1)

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
			FROM dbo.translog AS b WITH (NOLOCK, INDEX = IX_betrunning_custid)
				INNER JOIN @TempCust AS c ON b.custid = c.CustId
			WHERE b.statusID IN (0, 1)
		END

		IF @Username IS NULL OR @Username = '' OR @NumOfMem <= 5000
		BEGIN
			DELETE b
			FROM #Data AS b
			WHERE NOT EXISTS (SELECT 1 FROM #TempAg WHERE CustId = b.Recommend AND Currency = b.Currency)
		END
		ELSE
		BEGIN
			DELETE b
			FROM #Data AS b
			WHERE NOT EXISTS (SELECT 1 FROM @TempCust WHERE CustId = b.CustId)
				OR NOT EXISTS (SELECT 1 FROM #TempAg WHERE CustId = b.Recommend AND Currency = b.Currency)
		END

		IF EXISTS (SELECT TOP(1) 1 FROM #Data)
		BEGIN
			DECLARE @ShowSB BIT = 0

			IF ',' + @ProductList + ',' LIKE '%,SB,%'
			BEGIN
				SET @ShowSB = 1
			END

			IF 1 IN (@ShowBA)
				AND ',' + @ProductList + ',' NOT LIKE '%,SB,%'
			BEGIN
				SET @ProductList = 'SB,' + @ProductList
			END

			DECLARE @IsTest BIT = 0

			SELECT @IsTest = dbo.f_CheckSPVersion(@@PROCID)

			-- Get Sport/Bettype info
			UPDATE b
			SET
				BATransId = ba.TransID,
				Product = CASE
							WHEN s.ProductID = 6 THEN 'OneRNG'							-- RNG Casino
							WHEN s.ProductID = 8 THEN 'Keno'
							WHEN s.ProductID = 15 THEN 'CB'								-- Colossus Bet
							WHEN s.ProductID = 21 THEN 'AllBet'
							WHEN s.ProductID = 22 THEN 'VB'								-- Macau Games
							WHEN s.ProductID = 28 THEN 'Lottery'
							WHEN s.ProductID = 32 THEN 'PP'								-- Pragmatic Play Casino
							WHEN s.ProductID = 34 THEN 'CC'								-- Card Club(Arcadia Gaming)
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
							WHEN s.ProductID = 61 THEN 'HB'								-- Habanero
							WHEN s.ProductID = 62 THEN 'CG'								-- CG
							WHEN s.ProductID = 63 THEN 'SLT'							-- Sports Lottery
							WHEN s.ProductID = 66 THEN 'VGA'							-- Vgaming
							WHEN s.ProductID = 67 THEN 'AP'								-- AdvantPlay
							WHEN s.ProductID = 68 THEN 'APM'							-- AdvantPlay Mini
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
				INNER JOIN dbo.f_SportBettypeMatrix_Sel (0, 0, 0, 2, '', @ProductList, @IsTest) AS s ON b.bettype = s.bettype
				LEFT JOIN bodb_Licensee.dbo.LicenseeBATransaction_active AS ba WITH (NOLOCK) ON b.transid = ba.TransID

			IF @StatusFilter <> '1,2,3'
			BEGIN
				UPDATE b
				SET b.SettlementStatus = m.SettlementStatus
				FROM #Data AS b
					INNER JOIN dbo.match AS m WITH (NOLOCK) ON b.Product = 'SB' AND m.matchid = b.matchid

				IF ',' + @StatusFilter + ',' NOT LIKE '%,1,%'	-- Not include Running, Waiting
				BEGIN
					DELETE #Data
					WHERE Product <> 'SB'
						OR (Product = 'SB'
							AND (Status = 'Waiting'																										-- Waiting
								OR (Status = 'Running' AND ISNULL(SecAcceptFlag, 0) = 1 AND ISNULL(CheckTime, CURRENT_TIMESTAMP) > CURRENT_TIMESTAMP)	-- Waiting (Second Accept)
								OR (Status = 'Running' AND ISNULL(SettlementStatus, 0) & 13 = 0)								-- Running (normal)
								OR (Status = 'Running'			-- Cash Out All
									AND Stake = 0
									AND BetdaqId = 0
									AND ExtraInfo LIKE '%p25%')))
				END
				
				IF ',' + @StatusFilter + ',' NOT LIKE '%,2,%'		-- Not include Delay Payout
					OR ',' + @StatusFilter + ',' NOT LIKE '%,3,%'	-- Not include Under Settlement
				BEGIN
					DELETE #Data
					WHERE Product = 'SB'
						AND Status = 'Running'
						AND (ISNULL(SecAcceptFlag, 0) = 0 OR ISNULL(CheckTime, CURRENT_TIMESTAMP) <= CURRENT_TIMESTAMP)
						AND (Stake <> 0						-- Not Cash Out All
							OR BetdaqId <> 0
							OR ExtraInfo NOT LIKE '%p25%')
						AND ((',' + @StatusFilter + ',' NOT LIKE '%,2,%' AND ISNULL(SettlementStatus, 0) & 1 <> 0)			-- Delay Payout
							OR (',' + @StatusFilter + ',' NOT LIKE '%,3,%'
								AND ISNULL(SettlementStatus, 0) & 12 <> 0
								AND ISNULL(SettlementStatus, 0) & 1 = 0))		-- Under Settlement
				END
			END

			DELETE #Data
			WHERE Product = 'Unknown'
				OR Product IS NULL
				OR BetType IN (901, 902, 903, 904, 911, 912, 913, 914)
				OR BetType BETWEEN 801 AND 899
				OR (@ShowSB = 0
					AND Product IN ('SB', 'Parlay', 'Outright')
					AND BATransId IS NULL)
				OR (@ShowBA = 0
					AND Product IN ('SB', 'Parlay', 'Outright')
					 AND BATransId IS NOT NULL)

			DECLARE @Yesterday SMALLDATETIME = DATEADD(DAY, DATEDIFF(DAY, 1, CURRENT_TIMESTAMP), 0)

			IF ',' + @StatusFilter + ',' LIKE '%,1,%'	-- Yesterday and today bettransRnG/bettransLC running tickets
			BEGIN
				IF @Username IS NULL OR @Username = '' OR @NumOfMem > 5000		-- Licensee level (not input username of number of searched member > 5000)
				BEGIN
					-- bettransRnG
					INSERT INTO @TmpData
					SELECT
						b.RefNo,
						b.gameID AS BetType,
						CASE
							WHEN s.ProductID IN (6, 32, 42, 66) THEN ISNULL(AVG(CASE WHEN statusID IN (111, 112, 113) THEN ContributionRate END), 0)
							ELSE 0
						END AS Odds,
						CASE
							WHEN s.ProductID IN (6, 32, 42, 66) THEN ISNULL(SUM(BetStake), 0)
							ELSE 0
						END AS OddsSpread,
						SUM(b.stake) AS Stake,
						SUM(b.actual_stake) AS Actual_Stake,
						1 AS IsNew
					FROM dbo.bettransRnG AS b WITH (NOLOCK)
						INNER JOIN #TempAg AS a ON a.CustId = b.recommend
						INNER JOIN dbo.f_SportBettypeMatrix_Sel (0, 0, 0, 2, '', @ProductList, @IsTest) AS s ON b.gameID = s.bettype
					WHERE b.winlostdate >= @Yesterday AND b.statusID IN (0, 1)
					GROUP BY b.RefNo,
						b.gameID,
						s.ProductID

					-- bettransLC
					INSERT INTO @TmpData
					SELECT
						b.RefNo,
						b.gameID AS BetType,
						0 AS Odds,
						0 AS OddsSpread,
						SUM(b.stake) AS Stake,
						SUM(b.actual_stake) AS Actual_Stake,
						1 AS IsNew
					FROM dbo.bettransLC AS b WITH (NOLOCK)
						INNER JOIN #TempAg AS a ON a.CustId = b.recommend
						INNER JOIN dbo.f_SportBettypeMatrix_Sel (0, 0, 0, 2, '', @ProductList, @IsTest) AS s ON b.gameID = s.bettype
					WHERE b.winlostdate >= @Yesterday AND b.statusID IN (0, 1)
					GROUP BY b.RefNo,
						b.gameID
				END
				ELSE
				BEGIN
					-- bettransRnG
					INSERT INTO @TmpData
					SELECT
						b.RefNo,
						b.gameID AS BetType,
						CASE
							WHEN s.ProductID IN (6, 32, 42, 66) THEN ISNULL(AVG(CASE WHEN statusID IN (111, 112, 113) THEN ContributionRate END), 0)
							ELSE 0
						END AS Odds,
						CASE
							WHEN s.ProductID IN (6, 32, 42, 66) THEN ISNULL(SUM(BetStake), 0)
							ELSE 0
						END AS OddsSpread,
						SUM(b.stake) AS Stake,
						SUM(b.actual_stake) AS Actual_Stake,
						1 AS IsNew
					FROM dbo.bettransRnG AS b WITH (NOLOCK)
						INNER JOIN @TempCust AS a ON a.CustId = b.custid
						INNER JOIN dbo.f_SportBettypeMatrix_Sel (0, 0, 0, 2, '', @ProductList, @IsTest) AS s ON b.gameID = s.bettype
					WHERE b.winlostdate >= @Yesterday AND b.statusID IN (0, 1)
					GROUP BY b.RefNo,
						b.gameID,
						s.ProductID

					-- bettransLC
					INSERT INTO @TmpData
					SELECT
						b.RefNo,
						b.gameID AS BetType,
						0 AS Odds,
						0 AS OddsSpread,
						SUM(b.stake) AS Stake,
						SUM(b.actual_stake) AS Actual_Stake,
						1 AS IsNew
					FROM dbo.bettransLC AS b WITH (NOLOCK)
						INNER JOIN @TempCust AS a ON a.CustId = b.custid
						INNER JOIN dbo.f_SportBettypeMatrix_Sel (0, 0, 0, 2, '', @ProductList, @IsTest) AS s ON b.gameID = s.bettype
					WHERE b.winlostdate >= @Yesterday AND b.statusID IN (0, 1)
					GROUP BY b.RefNo,
						b.gameID
				END

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
						WHEN s.ProductID = 21 THEN 'AllBet'
						WHEN s.ProductID = 22 THEN 'VB'		-- Macau Games
						WHEN s.ProductID = 32 THEN 'PP'		-- Pragmatic Play Casino
						WHEN s.ProductID = 34 THEN 'CC'		-- Card Club (Arcadia Gaming)
						WHEN s.ProductID = 36 THEN 'SG'		-- Spadegaming
						WHEN s.ProductID = 39 THEN 'SAG'	-- SA Gaming
						WHEN s.ProductID = 42 THEN 'SBC'	-- Saba.club
						WHEN s.ProductID = 45 THEN 'SXG'	-- Sexy Gaming
						WHEN s.ProductID = 51 THEN 'WM'		-- WM Live Casino
						WHEN s.ProductID = 55 THEN 'PGS'	-- PG Soft
						WHEN s.ProductID = 56 THEN 'JK'		-- Joker
						WHEN s.ProductID = 57 THEN 'BG'		-- Big Gaming
						WHEN s.ProductID = 59 THEN 'GDG'	-- GDG
						WHEN s.ProductID = 61 THEN 'HB'		-- Habanero
						WHEN s.ProductID = 62 THEN 'CG'		-- CG
						WHEN s.ProductID = 66 THEN 'VGA'	-- Vgaming
						WHEN s.ProductID = 67 THEN 'AP'		-- AdvantPlay
						WHEN s.ProductID = 68 THEN 'APM'	-- AdvantPlay Mini
						ELSE 'Unknown'
					END AS Product,
					s.RefTable
				FROM dbo.bettrans AS b WITH (NOLOCK)
					INNER JOIN @TmpData AS t ON t.RefNo = b.transid AND t.BetType = b.BetType
					INNER JOIN dbo.f_SportBettypeMatrix_Sel (0, 0, 0, 2, '', '', @IsTest) AS s ON b.bettype = s.bettype
				WHERE t.IsNew = 1
			END

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

			-- Get exchange rate
			INSERT INTO #ExchangeRate
			SELECT
				e.ExchangeId,
				e.Rate
			FROM dbo.Lrf_f_GetExchangeRate(DATEADD(DAY, DATEDIFF(DAY, 0, GETDATE()), 0), DATEADD(DAY, DATEDIFF(DAY, 0, GETDATE()), 0), @BaseCurrency, '') AS e
			WHERE EXISTS (SELECT 1 FROM #Data WHERE Currency = e.ExchangeId)

			-- Get sort text
			IF @ConvertToBaseCur = 1 AND @Sort LIKE '%Stake%'
			BEGIN
				DECLARE @CharIndex TINYINT

				SELECT @CharIndex = CHARINDEX(' ', @Sort, 1)

				SELECT @Sort = SUBSTRING(@Sort, 0, @CharIndex) + ' * ISNULL(e.Rate, 1)' + SUBSTRING(@Sort, @CharIndex, LEN(@Sort))
			END

			-- Return data
			SELECT
				@TotalRows = COUNT(b.TransId),
				@SumStake = SUM(b.Stake * ISNULL(e.Rate, 1))
			FROM #Data AS b
				LEFT JOIN #ExchangeRate AS e ON e.ExchangeId = b.Currency

			IF @ConvertToBaseCur = 0
			BEGIN
				DELETE FROM #ExchangeRate
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
							ROW_NUMBER() OVER (ORDER BY ' + @Sort +') AS RowNum,
							d.*
						FROM #Data AS d' +
						CASE
							WHEN @Sort LIKE '%e.Rate%' THEN N'
							LEFT JOIN #ExchangeRate AS e ON e.ExchangeId = d.Currency'
							ELSE N' '
						END + N'
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
								WHEN b.Product IN ('VB', 'PP', 'CC', 'SG', 'OneRNG', 'Allbet', 'CB', 'SBC', 'SXG', 'SAG', 'PGS', 'JK', 
									'GDG', 'HB', 'WM', 'BG', 'VGA', 'CG', 'AP', 'APM') THEN b.MatchId
								WHEN b.Product IN ('Keno', 'Lottery', 'TG', 'I4D', 'VRG', 'H5LG', 'SLT', 'VS3') THEN b.ProductId
								WHEN b.Product IN ('SB', 'NG', 'VS', 'VS2') THEN m.sporttype
								WHEN b.Product IN ('Outright') THEN l.sporttype
								WHEN b.Product IN ('VR') THEN vr.SportType
								ELSE 0
							END,
				BetTeam = CASE
								WHEN b.Product IN ('SB', 'NG', 'VS', 'VS2', 'Parlay', 'ParlayVS2') THEN b.BetTeam
								ELSE ''
							END,
				Hdp1 = CASE
							WHEN b.Product IN ('SB', 'NG', 'VS', 'VS2', 'VR', 'Parlay', 'ParlayVS2') THEN b.Hdp1
							ELSE 0
						END,
				Hdp2 = CASE
							WHEN b.Product IN ('SB', 'VS', 'VS2', 'VR', 'Parlay', 'ParlayVS2') THEN b.Hdp2
							ELSE 0
						END,
				OddsType = CASE
							WHEN b.Product IN ('SB', 'NG', 'VS', 'VS2', 'Outright', 'VR') THEN b.OddsType
							ELSE 0
						END,
				Odds = CASE
							WHEN b.Product IN ('OneRNG', 'PP', 'SBC', 'VGA') AND x.Odds IS NOT NULL THEN x.Odds
							WHEN b.Product IN ('SB', 'NG', 'VS', 'VS2', 'Outright', 'VR', 'Parlay', 'Keno', 'ParlayVS2', 'Lottery', 'TG', 'I4D', 
								'VRG', 'SLT', 'H5LG', 'VS3') THEN b.Odds
							ELSE 0
						END,
				MOdds = CASE 
							WHEN b.Product IN ('SB', 'NG', 'VS', 'VS2', 'Outright', 'VR', 'Parlay', 'ParlayVS2')  THEN b.modds 
							ELSE 0
						END,
				OddsSpread = CASE
								WHEN b.Product IN ('OneRNG', 'PP', 'SBC', 'VGA') AND x.OddsSpread IS NOT NULL THEN x.OddsSpread
								WHEN b.Product IN ('SB') THEN ISNULL(b.oddsspread, 0)
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
									WHEN b.Product IN ('SB', 'NG', 'VS', 'VS2') THEN b.liveindicator
									ELSE 0
								END,
				LiveHomeScore = CASE
									WHEN b.Product IN ('SB', 'NG', 'VS', 'VS2', 'Outright', 'VR', 'Parlay', 'ParlayVS2') THEN b.livehomescore
									ELSE 0
								END,
				LiveAwayScore = CASE
									WHEN b.Product IN ('SB', 'NG', 'VS', 'VS2', 'Outright', 'VR') THEN b.liveawayscore
									ELSE 0
								END,
				LeagueId = CASE
								WHEN b.Product IN ('SB', 'NG', 'VS', 'VS2') THEN m.leagueid
								WHEN b.Product IN ('Outright') THEN o.leagueid
								WHEN b.Product IN ('VR') THEN vr.LeagueID
								ELSE 0
							END,
				MatchId = CASE
								WHEN b.Product IN ('SB', 'NG', 'VS', 'VS2') THEN m.matchid
								WHEN b.Product IN ('VR') THEN b.matchid
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
								ELSE b.WinLostDate
							END,
				HomeId = CASE
							WHEN b.Product IN ('SB', 'NG', 'VS', 'VS2') THEN m.homeid
							WHEN b.Product IN ('Outright') THEN o.teamid
							WHEN b.Product IN ('VR') THEN vo.RacerID
							ELSE 0
						END,
				AwayId = CASE
							WHEN b.Product IN ('SB', 'NG', 'VS', 'VS2') THEN m.awayid
							ELSE 0
						END,
				BetStatus = CASE
								WHEN b.Product IN ('SB', 'NG', 'VS', 'VS2') THEN m.betstatus
								ELSE ''
							END,
				IsNeutral = CASE
								WHEN b.Product IN ('SB', 'NG', 'VS', 'VS2') THEN ISNULL(m.IsNeutral, 0)
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
								WHEN b.Product IN ('SB', 'Parlay', 'ParlayVS2') THEN ISNULL(b.betcheck, '')
								WHEN b.Product IN ('Keno') THEN ISNULL(b.custom2, '')
								WHEN b.Product IN ('VRG', 'H5LG', 'SLT') THEN ISNULL(b.Gameid3rd, '')
								WHEN b.Product IN ('CB') THEN ISNULL(b.Tranid3rd, '')
								WHEN b.Product IN ('VS3') THEN ISNULL(b.Custom1, '')
								ELSE ''
							END,
				TransDesc = CASE
								WHEN b.Product IN ('SB', 'VS2', 'Keno', 'Lottery', 'OneRNG', 'VB', 'FW', 'PP', 
									'CC', 'SG', 'VRG', 'TG', 'I4D', 'PGS', 'JK', 'H5LG', 'SLT', 'HB', 'CG', 'AP', 'APM', 'VS3') THEN ISNULL(b.transdesc, '')
								ELSE ''
							END,
				BetdaqId = CASE
								WHEN b.Product IN ('SB') THEN ISNULL(b.betdaqid, -1)
								ELSE -1
							END,
				ExtraInfo = CASE
								WHEN b.Product IN ('SB', 'Parlay', 'Outright', 'NG', 'VS', 'VS2', 'ParlayVS2', 'VR') THEN ISNULL(b.ExtraInfo, '')
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
				LEFT JOIN dbo.match AS m WITH (NOLOCK) ON b.Product IN ('SB', 'NG', 'VS', 'VS2') AND b.matchid = m.matchid
				LEFT JOIN dbo.outright AS o WITH (NOLOCK) ON b.Product IN ('Outright') AND b.matchid = o.orid
				LEFT JOIN dbo.League AS l WITH (NOLOCK) ON b.Product IN ('Outright') AND o.leagueID = l.leagueID
				LEFT JOIN dbo.VSOutright AS vo WITH (NOLOCK) ON b.Product IN ('VR') AND b.oddsid = vo.Orid
				LEFT JOIN dbo.VSRaceInfo AS vr WITH (NOLOCK) ON b.Product IN ('VR') AND vr.EventID = vo.EventID
		END
	END

	-- Get ticket detail
	-- Virtual Sports
	IF EXISTS (SELECT 1 FROM #PagingData WHERE Product = 'VR')
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
			LEFT JOIN #ExchangeRate AS e ON e.ExchangeId = b.Currency
		WHERE b.Product = 'VR'
			AND sbt.ProductID = 5
			AND sbt.EventType = 3
	END

	SELECT
		c.username,
		SUBSTRING(c.username2, CHARINDEX('$', c.username2) + 1, LEN(c.username2) - CHARINDEX('$', c.username2)) AS NickName,
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
		a.Placing,
		a.BetStatus,
		a.ShowTime,
		a.Currency,
		a.Stake * ISNULL(e.Rate, 1) AS Stake,
		a.Actual_Stake * ISNULL(e.Rate, 1) AS Actual_Stake,
		a.Ip,
		a.BetFrom,
		a.BetCheck,
		a.TransDesc,
		a.BetdaqId,
		a.ExtraInfo,
		a.OriginalStake * ISNULL(e.Rate, 1) AS OriginalStake,
		a.OriginalBetType,
		a.WalletType,
		a.RefCode
	FROM
		#PagingData AS a
		INNER JOIN dbo.Customer AS c WITH (NOLOCK) ON c.custid = a.CustId
		LEFT JOIN #ExchangeRate AS e ON e.ExchangeId = a.Currency
	ORDER BY a.RowNum ASC

	SELECT DISTINCT * FROM @Detail

	DROP TABLE #TempAg
	DROP TABLE #Data
	DROP TABLE #PagingData
	DROP TABLE #ExchangeRate
END
GO
