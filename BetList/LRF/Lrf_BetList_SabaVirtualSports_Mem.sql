/*<info serverAlias="DBACC-bodb02" executers="wsv_lap" viewers="" isFunction="0" isNested="0"></info>*/

ALTER PROCEDURE [dbo].[Lrf_BetList_SabaVirtualSports_Mem]
	@AgentList		VARCHAR(MAX),
	@CustId			INT,
	@FromDate		SMALLDATETIME,
	@ToDate			SMALLDATETIME,
	@MoveBetsDay	SMALLDATETIME,
	@BalanceUpDay	SMALLDATETIME,
	@SportType		SMALLINT		= 0,
	@LeagueId		INT				= 0,
	@DrawFilter		SMALLINT		= 1,
	@BaseCurrency	VARCHAR(12),
	@PageSize		INT				= 1000,
	@PageIndex		INT				= 1,
	@TotalRows		INT				= 0 OUTPUT,
	@SumWinLost		MONEY			= 0 OUTPUT,
	@SumLicenseeWL	MONEY			= 0 OUTPUT,
	@SumComm		MONEY			= 0 OUTPUT,
	@SumPlayerComm	MONEY			= 0 OUTPUT
AS

/*
	Created: 20201002@Kos
	Task: LAP - Saba Virtual Sports Report bet list
	DB: DBACC.bodb02

	Revisions:
		- 20201002@Kos: New SP [RedmineID: #141454]
		- 20210520@Kos: Support Saba Soccer PinGoal [RedmineID: #155335]
		- 20210929@Kos: Extend length to support IPv6 [Redmine: 162342]
		- 20211029@Kos: Decompress IP in bk range [Redmine: 162342]
		- 20220222@Kos: Support Saba Basketball PinGoal [RedmineID: #167859]
		- 20220922@Kos: Support crypto currency [Redmine: 177481]
		- 20221207@Kos: Support Saba E-Sports PinGoal [RedmineID: #181224]
		- 20230703@Kos: Support Saba Tennis [RedmineID: #190465]
		- 20240307@Kos: Support Saba Ice Hockey [RedmineID: #201283]
		- 20240425@Kos: Return LeagueGroupId to support Jollysports [Redmine: #203258]
		- 20240509@Kos: Support Saba Kabaddi [RedmineID: #203612]
		- 20250225@Kos: Fix bug FLOAT rounding [#Redmine: 194970]
		- 20250313@Kos: Remove BA [RedmineID: #216882]
		- 20250506@Kos: Support Saba Soccer Marble [#Redmine: 225015]

	Param's Explanation:
		+ @DrawFilter:
			- 1: Normal,
			- 2: No Draw,
			- 3: No Draw for Turnover only
		+ @SportType: sport type
			- -2: Saba Soccer (sporttype: 1, LeagueGroupID: 42, 74) + Saba Futsal (sporttype: 1, LeagueGroupID: 108)
			- -4: Saba Soccer PinGoal (sporttype: 1, LeagueGroupID: 113)
			- -5: Saba Basketball (sporttype: 2, LeagueGroupID: 42)
			- -6: Saba Basketball PinGoal (sporttype: 2, LeagueGroupID: 122)
			- -7: Saba E-Sports PinGoal (sporttype: 43, LeagueGroupID: 151)
			- -8: Saba Cricket (sporttype: 50, LeagueGroupID: 42)
			- -9: Saba Tennis (sporttype: 5, LeagueGroupID: 42)
			- -10: Saba Ice Hockey (sporttype: 4, LeagueGroupID: 42)
			- -11: Saba Kabaddi (sporttype: 47, LeagueGroupID: 42)
			- -12: Saba Soccer Marble (sporttype: 1, LeagueGroupID: 252)
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
	DECLARE @SportBettype TABLE(ProductID TINYINT, BetType SMALLINT, EventType TINYINT)

	DECLARE @IsTest BIT = 0

	SELECT @IsTest = dbo.f_CheckSPVersion(@@PROCID)

	INSERT INTO @SportBettype
	SELECT ProductID, BetType, EventType
	FROM dbo.f_SportBettypeMatrix_Sel (0, 0, 0, 2, '', '', @IsTest)
	WHERE ProductID IN (1, 25)
		AND BetType NOT IN (9, 29, 914, 901, 902, 903, 904)
		AND BetType NOT BETWEEN 801 AND 899

	DECLARE @CutOffDate SMALLDATETIME = '2023-07-01'

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
		AWinLost			MONEY,
		WinLost				MONEY,
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
		LeagueGroupId		SMALLINT,
		MatchId				INT,
		MatchCode			NVARCHAR(50),
		EventDate			DATETIME,
		HomeId				INT,
		AwayId				INT,
		BetStatus			NVARCHAR(50),
		IsNeutral			BIT,
		BetCheck			NVARCHAR(50),
		ComStatus			NVARCHAR(20),
		TransDesc			NVARCHAR(1000),
		BetdaqId			BIGINT,
		ExtraInfo			VARCHAR(1000),
		OriginalStake		MONEY,
		OriginalBetType		SMALLINT,
		WalletType			TINYINT,
		RefCode				BIGINT,
		TableID				TINYINT,
		Product				VARCHAR(30)
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
		AWinLost			MONEY,
		WinLost				MONEY,
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
		LeagueGroupId		SMALLINT,
		MatchId				INT,
		MatchCode			NVARCHAR(50),
		EventDate			DATETIME,
		HomeId				INT,
		AwayId				INT,
		BetStatus			NVARCHAR(50),
		IsNeutral			BIT,
		BetCheck			NVARCHAR(50),
		ComStatus			NVARCHAR(20),
		TransDesc			NVARCHAR(1000),
		BetdaqId			BIGINT,
		ExtraInfo			VARCHAR(1000),
		OriginalStake		MONEY,
		OriginalBetType		SMALLINT,
		WalletType			TINYINT,
		RefCode				BIGINT,
		TableID				TINYINT,
		Product				VARCHAR(30)
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
				AND b.statusID IN (111, 112, 113)
		END

		-- bettrans14
		IF @FromDate <= @MoveBetsDay AND @ToDate >= @BalanceUpDay
		BEGIN
			IF @ToDate >= @MoveBetsDay
				SET @TempToDate = @MoveBetsDay
			ELSE
				SET @TempToDate = @ToDate

			IF @FromDate < @BalanceUpDay
				SET @TempFromDate = @BalanceUpDay
			ELSE
				SET @TempFromDate = @FromDate

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
				2 AS TableID
			FROM dbo.bettrans14 AS b WITH (NOLOCK, INDEX = IX_memberStatement14)
			WHERE b.custid = @CustId
				AND b.winlostdate BETWEEN @TempFromDate AND @TempToDate
				AND b.statusID IN (111, 112, 113)
		END

		-- bettrans_bk
		IF @FromDate <= @BalanceUpDay
		BEGIN
			IF @ToDate >= DATEADD(dd, -1, @BalanceUpDay)
				SET @TempToDate = DATEADD(dd, -1, @BalanceUpDay)
			ELSE
				SET @TempToDate = @ToDate

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
				dp.IP,
				b.matchid,
				b.betcheck,
				b.comstatus,
				b.transdesc,
				b.betdaqid,
				b.ExtraInfo,
				b.WalletType,
				ISNULL(b.RefCode, 0),
				3 AS TableID
			FROM bodb_Archive.dbo.bettrans_bk AS b WITH (NOLOCK, INDEX = IX_custid)
				CROSS APPLY dbo.f_IP_Decompress(b.ip) AS dp
			WHERE b.custid = @CustId
				AND b.winlostdate BETWEEN @FromDate AND @TempToDate
				AND b.statusID IN (111, 112, 113)

			-- Get more info for CashOut tickets
			IF EXISTS (SELECT TOP(1) 1 FROM #Data WHERE BetType = 911 AND TableID = 3)
			BEGIN
				UPDATE b
				SET b.Odds = ob.odds,
					b.LiveIndicator = ob.liveindicator,
					b.LiveHomeScore = ob.livehomescore,
					b.LiveAwayScore = ob.liveawayscore,
					b.OriginalBetType = ob.bettype,
					b.BetdaqId = ob.transid
				FROM #Data AS b
					INNER JOIN bodb_Archive.dbo.bettrans_bk AS ob WITH (NOLOCK) ON b.RefNo = ob.transid
				WHERE b.BetType = 911 AND b.TableID = 3
			END

			IF EXISTS (SELECT TOP(1) 1 FROM #Data WHERE BetType = 912 AND TableID = 3)
			BEGIN
				UPDATE b
				SET b.Odds = ob.odds,
					b.LiveIndicator = ob.liveindicator,
					b.LiveHomeScore = ob.livehomescore,
					b.LiveAwayScore = ob.liveawayscore,
					b.OriginalBetType = ob.bettype,
					b.BetdaqId = ob.transid,
					b.Stake = cob.stake,
					b.Comm = ISNULL(cb.awinlost, 0)
				FROM #Data AS b
					INNER JOIN bodb_Archive.dbo.bettrans_bk AS cob WITH (NOLOCK) ON b.RefNo = cob.transid
					INNER JOIN bodb_Archive.dbo.bettrans_bk AS ob WITH (NOLOCK) ON cob.RefNo = ob.transid
					LEFT JOIN #Data AS cb
						ON cb.RefNo = b.RefNo
						AND cb.BetType = 913
						AND cb.custid = @CustId
						AND cb.winlostdate = b.WinLostDate
				WHERE b.BetType = 912 AND b.TableID = 3
			END
		END

		DELETE b
		FROM #Data AS b
		WHERE NOT EXISTS (SELECT 1 FROM @TempAg WHERE CustId = b.Recommend AND Currency = b.Currency)
			OR b.BetType = 913
			OR (@DrawFilter = 2
				AND b.Status = 'DRAW'
				AND ABS(b.MOdds) <> 0.25)

		IF EXISTS (SELECT TOP(1) 1 FROM #Data)
		BEGIN
			-- Get Sport/Bettype info
			UPDATE b
			SET
				Product = CASE
							WHEN s.ProductID = 25 THEN 'CO'								-- Cash Out
							WHEN s.EventType = 1 AND s.ProductID = 1 THEN 'SB'			-- Sportsbook
							WHEN s.EventType = 2 AND s.ProductID = 1 THEN 'Outright'
							ELSE 'Unknown'
						END
			FROM #Data AS b
				INNER JOIN @SportBettype AS s ON b.bettype = s.bettype

			DECLARE @SabaVirtualSportLeague TABLE (LeagueId INT)

			INSERT INTO @SabaVirtualSportLeague
			SELECT leagueid
			FROM dbo.league WITH (NOLOCK)
			WHERE (@LeagueId = 0 OR leagueid = @LeagueId)
				AND (@SportType = 0
					OR sporttype = CASE
									WHEN @SportType IN (-2, -4, -12) THEN 1
									WHEN @SportType IN (-5, -6) THEN 2
									WHEN @SportType = -10 THEN 4
									WHEN @SportType = -9 THEN 5
									WHEN @SportType = -7 THEN 43
									WHEN @SportType = -11 THEN 47
									WHEN @SportType = -8 THEN 50
									ELSE @SportType
								END)
				AND ((@SportType IN (0, -2) AND sporttype = 1 AND LeagueGroupID IN (42, 74, 108))
					OR (@SportType IN (0, -4) AND sporttype = 1 AND LeagueGroupID IN (113))
					OR (@SportType IN (0, -5) AND sporttype = 2 AND LeagueGroupID IN (42))
					OR (@SportType IN (0, -6) AND sporttype = 2 AND LeagueGroupID IN (122))
					OR (@SportType IN (0, -10) AND sporttype = 4 AND LeagueGroupID IN (42))
					OR (@SportType IN (0, -9) AND sporttype = 5 AND LeagueGroupID IN (42))
					OR (@SportType IN (0, -7) AND sporttype = 43 AND LeagueGroupID IN (151))
					OR (@SportType IN (0, -11) AND sporttype = 47 AND LeagueGroupID IN (42))
					OR (@SportType IN (0, -8) AND sporttype = 50 AND LeagueGroupID IN (42))
					OR (@SportType IN (0, -12) AND sporttype = 1 AND LeagueGroupID IN (252)))

			DELETE b
			FROM #Data AS b
				INNER JOIN dbo.match AS m WITH (NOLOCK) ON m.matchid = b.MatchId
			WHERE b.TableID = 1
				AND b.Product IN ('SB')
				AND (m.leagueid NOT IN (SELECT LeagueId FROM @SabaVirtualSportLeague)
					OR (m.sporttype = 5 AND b.WinLostDate < @CutOffDate))

			DELETE b
			FROM #Data AS b
				INNER JOIN dbo.match14 AS m WITH (NOLOCK) ON m.matchid = b.MatchId
			WHERE b.TableID = 2
				AND b.Product IN ('SB')
				AND (m.leagueid NOT IN (SELECT LeagueId FROM @SabaVirtualSportLeague)
					OR (m.sporttype = 5 AND b.WinLostDate < @CutOffDate))

			DELETE b
			FROM #Data AS b
				INNER JOIN bodb_Archive.dbo.match_bk AS m WITH (NOLOCK) ON m.matchid = b.MatchId
			WHERE b.TableID = 3
				AND b.Product IN ('SB', 'CO')
				AND (m.leagueid NOT IN (SELECT LeagueId FROM @SabaVirtualSportLeague)
					OR (m.sporttype = 5 AND b.WinLostDate < @CutOffDate))

			DELETE b
			FROM #Data AS b
				INNER JOIN dbo.outright AS o WITH (NOLOCK) ON o.orid = b.MatchId
				INNER JOIN dbo.league AS l WITH (NOLOCK) ON l.leagueid = o.leagueid
			WHERE b.TableID = 1
				AND b.Product = ('Outright')
				AND (o.leagueid NOT IN (SELECT LeagueId FROM @SabaVirtualSportLeague)
					OR (l.sporttype = 5 AND b.WinLostDate < @CutOffDate))

			DELETE b
			FROM #Data AS b
				INNER JOIN dbo.outright14 AS o WITH (NOLOCK) ON o.orid = b.MatchId
				INNER JOIN dbo.league AS l WITH (NOLOCK) ON l.leagueid = o.leagueid
			WHERE b.TableID = 2
				AND b.Product = ('Outright')
				AND (o.leagueid NOT IN (SELECT LeagueId FROM @SabaVirtualSportLeague)
					OR (l.sporttype = 5 AND b.WinLostDate < @CutOffDate))

			DELETE b
			FROM #Data AS b
				INNER JOIN bodb_Archive.dbo.outright_bk AS o WITH (NOLOCK) ON o.orid = b.MatchId
				INNER JOIN dbo.league AS l WITH (NOLOCK) ON l.leagueid = o.leagueid
			WHERE b.TableID = 3
				AND b.Product = ('Outright')
				AND (o.leagueid NOT IN (SELECT LeagueId FROM @SabaVirtualSportLeague)
					OR (l.sporttype = 5 AND b.WinLostDate < @CutOffDate))

			DELETE #Data
			WHERE Product = 'Unknown'
				OR Product IS NULL
				OR BetType IN (901, 902, 903, 904, 914)
				OR BetType BETWEEN 801 AND 899

			UPDATE #Data
			SET
				WinLost = WinLost - Actual_Stake,
				LicenseeWL = - (WinLost - Actual_Stake)

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

			DECLARE @Username VARCHAR(50)

			SELECT @Currency = currency,
				@Username = username,
				@Nickname = SUBSTRING(username2, CHARINDEX('$', username2) + 1, LEN(username2) - CHARINDEX('$', username2))
			FROM dbo.Customer WITH (NOLOCK)
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
				FROM dbo.Lrf_f_GetExchangeRate(@ExFromDate, @ExToDate, @BaseCurrency, '') AS e
				WHERE e.ExchangeId = @Currency
					AND EXISTS (SELECT 1 FROM #Data WHERE WinLostDate BETWEEN e.FromDate AND e.ToDate)
			END

			-- Return data
			SELECT
				@TotalRows		= COUNT(b.TransId),
				@SumWinlost		= SUM(b.WinLost * ISNULL(e.Rate, 1)),
				@SumLicenseeWL	= SUM(b.LicenseeWL * ISNULL(e.Rate, 1)),
				@SumComm		= SUM(b.Comm * ISNULL(e.Rate, 1)),
				@SumPlayerComm	= SUM(b.PlayerComm * ISNULL(e.Rate, 1))
			FROM #Data AS b
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
					SportType = CASE
									WHEN b.Product IN ('SB') THEN m.sporttype
									WHEN b.Product IN ('Outright') THEN l.sporttype
									ELSE 0
								END,
					BetTeam = CASE
									WHEN b.Product IN ('SB') THEN b.BetTeam
									ELSE ''
								END,
					Hdp1 = CASE
								WHEN b.Product IN ('SB') THEN b.Hdp1
								ELSE 0
							END,
					Hdp2 = CASE
								WHEN b.Product IN ('SB') THEN b.Hdp2
								ELSE 0
							END,
					OddsType = CASE
								WHEN b.Product IN ('SB') THEN b.OddsType
								ELSE 0
							END,
					Odds = CASE
								WHEN b.Product IN ('SB', 'Outright') THEN b.Odds
								ELSE 0
							END,
					MOdds = CASE
								WHEN b.Product IN ('SB', 'Outright')  THEN b.modds 
								ELSE 0
							END,
					SettlementStatus = CASE
										WHEN b.Product = 'SB' THEN ISNULL(m.SettlementStatus, 0)
										ELSE 0
									END,
					LiveIndicator = CASE
										WHEN b.Product IN ('SB') THEN b.liveindicator
										ELSE 0
									END,
					LiveHomeScore = CASE
										WHEN b.Product IN ('SB', 'Outright') THEN b.livehomescore
										ELSE 0
									END,
					LiveAwayScore = CASE
										WHEN b.Product IN ('SB', 'Outright') THEN b.liveawayscore
										ELSE 0
									END,
					LeagueId = CASE
									WHEN b.Product IN ('SB') THEN m.leagueid
									WHEN b.Product IN ('Outright') THEN o.leagueid
									ELSE 0
								END,
					LeagueGroupId = CASE
										WHEN b.Product IN ('SB') THEN le.LeagueGroupID
										ELSE 0
									END,
					MatchId = CASE
									WHEN b.Product IN ('SB') THEN m.matchid
									ELSE 0
								END,
					MatchCode = CASE
									WHEN b.Product IN ('SB') THEN m.matchcode
									ELSE ''
								END,
					EventDate = CASE
								WHEN b.Product IN ('SB') THEN m.GlobalShowTime
								ELSE b.WinLostDate
							END,
					HomeId = CASE
								WHEN b.Product IN ('SB') THEN m.homeid
								WHEN b.Product IN ('Outright') THEN o.teamid
								ELSE 0
							END,
					AwayId = CASE
								WHEN b.Product IN ('SB') THEN m.awayid
								ELSE 0
							END,
					BetStatus = CASE
									WHEN b.Product IN ('SB') THEN m.betstatus
									ELSE ''
								END,
					IsNeutral = CASE
									WHEN b.Product IN ('SB') THEN ISNULL(m.IsNeutral, 0)
									ELSE 0
								END,
					BetCheck = CASE
									WHEN b.Product IN ('SB') THEN ISNULL(b.betcheck, '')
									ELSE ''
								END,
					TransDesc = CASE
									WHEN b.Product IN ('SB') THEN ISNULL(b.transdesc, '')
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
									WHEN b.Product IN ('SB', 'Outright') THEN ISNULL(b.ExtraInfo, '')
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
					LEFT JOIN dbo.match AS m WITH (NOLOCK) ON b.Product IN ('SB') AND b.matchid = m.matchid
					LEFT JOIN dbo.League AS le WITH (NOLOCK) ON b.Product IN ('SB') AND le.leagueid = m.leagueid
					LEFT JOIN dbo.outright AS o WITH (NOLOCK) ON b.Product IN ('Outright') AND b.matchid = o.orid
					LEFT JOIN dbo.League AS l WITH (NOLOCK) ON b.Product IN ('Outright') AND o.leagueID = l.leagueID
				WHERE b.TableID = 1
			END

			-- bettrans14
			IF EXISTS (SELECT TOP(1) 1 FROM #PagingData WHERE TableID = 2)
			BEGIN
				UPDATE b
				SET
					SportType = CASE
									WHEN b.Product IN ('SB') THEN m.sporttype
									WHEN b.Product IN ('Outright') THEN l.sporttype
									ELSE 0
								END,
					BetTeam = CASE
									WHEN b.Product IN ('SB') THEN b.BetTeam
									ELSE ''
								END,
					Hdp1 = CASE
								WHEN b.Product IN ('SB') THEN b.Hdp1
								ELSE 0
							END,
					Hdp2 = CASE
								WHEN b.Product IN ('SB') THEN b.Hdp2
								ELSE 0
							END,
					OddsType = CASE
								WHEN b.Product IN ('SB') THEN b.OddsType
								ELSE 0
							END,
					Odds = CASE
								WHEN b.Product IN ('SB', 'Outright') THEN b.Odds
								ELSE 0
							END,
					MOdds = CASE 
								WHEN b.Product IN ('SB', 'Outright') THEN b.modds 
								ELSE 0
							END,
					SettlementStatus = 0,
					LiveIndicator = CASE
										WHEN b.Product IN ('SB') THEN b.liveindicator
										ELSE 0
									END,
					LiveHomeScore = CASE
										WHEN b.Product IN ('SB', 'Outright') THEN b.livehomescore
										ELSE 0
									END,
					LiveAwayScore = CASE
										WHEN b.Product IN ('SB', 'Outright') THEN b.liveawayscore
										ELSE 0
									END,
					LeagueId = CASE
									WHEN b.Product IN ('SB') THEN m.leagueid
									WHEN b.Product IN ('Outright') THEN o.leagueid
									ELSE 0
								END,
					LeagueGroupId = CASE
										WHEN b.Product IN ('SB') THEN le.LeagueGroupID
										ELSE 0
									END,
					MatchId = CASE
									WHEN b.Product IN ('SB') THEN m.matchid
									ELSE 0
								END,
					MatchCode = CASE
									WHEN b.Product IN ('SB') THEN m.matchcode
									ELSE ''
								END,
					EventDate = CASE
								WHEN b.Product IN ('SB') THEN m.GlobalShowTime
								ELSE b.WinLostDate
							END,
					HomeId = CASE
								WHEN b.Product IN ('SB') THEN m.homeid
								WHEN b.Product IN ('Outright') THEN o.teamid
								ELSE 0
							END,
					AwayId = CASE
								WHEN b.Product IN ('SB') THEN m.awayid
								ELSE 0
							END,
					BetStatus = CASE
									WHEN b.Product IN ('SB') THEN m.betstatus
									ELSE ''
								END,
					IsNeutral = CASE
									WHEN b.Product IN ('SB') THEN ISNULL(m.IsNeutral, 0)
									ELSE 0
								END,
					BetCheck = CASE
									WHEN b.Product IN ('SB') THEN ISNULL(b.betcheck, '')
									ELSE ''
								END,
					TransDesc = CASE
									WHEN b.Product IN ('SB') THEN ISNULL(b.transdesc, '')
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
									WHEN b.Product IN ('SB', 'Outright') THEN ISNULL(b.ExtraInfo, '')
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
					LEFT JOIN dbo.match14 AS m WITH (NOLOCK) ON b.Product IN ('SB') AND b.matchid = m.matchid
					LEFT JOIN dbo.League AS le WITH (NOLOCK) ON b.Product IN ('SB') AND le.leagueid = m.leagueid
					LEFT JOIN dbo.outright14 AS o WITH (NOLOCK) ON b.Product IN ('Outright') AND b.matchid = o.orid
					LEFT JOIN dbo.League AS l WITH (NOLOCK) ON b.Product IN ('Outright') AND o.leagueID = l.leagueID
				WHERE b.TableID = 2
			END

			-- bettrans_bk
			IF EXISTS (SELECT TOP(1) 1 FROM #PagingData WHERE TableID = 3)
			BEGIN
				UPDATE b
				SET
					SportType = CASE
									WHEN b.Product IN ('SB', 'CO') THEN m.sporttype
									WHEN b.Product IN ('Outright') THEN l.sporttype
									ELSE 0
								END,
					BetTeam = CASE
									WHEN b.Product IN ('SB', 'CO') THEN b.BetTeam
									ELSE ''
								END,
					Hdp1 = CASE
								WHEN b.Product IN ('SB', 'CO') THEN b.Hdp1
								ELSE 0
							END,
					Hdp2 = CASE
								WHEN b.Product IN ('SB', 'CO') THEN b.Hdp2
								ELSE 0
							END,
					OddsType = CASE
								WHEN b.Product IN ('SB', 'CO') THEN b.OddsType
								ELSE 0
							END,
					Odds = CASE
								WHEN b.Product IN ('SB', 'CO', 'Outright') THEN b.Odds
								ELSE 0
							END,
					MOdds = CASE 
								WHEN b.Product IN ('SB', 'CO', 'Outright')  THEN b.modds 
								ELSE 0
							END,
					SettlementStatus = 0,
					LiveIndicator = CASE
										WHEN b.Product IN ('SB', 'CO') THEN b.liveindicator
										ELSE 0
									END,
					LiveHomeScore = CASE
										WHEN b.Product IN ('SB', 'CO', 'Outright') THEN b.livehomescore
										ELSE 0
									END,
					LiveAwayScore = CASE
										WHEN b.Product IN ('SB', 'CO', 'Outright') THEN b.liveawayscore
										ELSE 0
									END,
					LeagueId = CASE
									WHEN b.Product IN ('SB', 'CO') THEN m.leagueid
									WHEN b.Product IN ('Outright') THEN o.leagueid
									ELSE 0
								END,
					LeagueGroupId = CASE
										WHEN b.Product IN ('SB') THEN le.LeagueGroupID
										ELSE 0
									END,
					MatchId = CASE
									WHEN b.Product IN ('SB', 'CO') THEN m.matchid
									ELSE 0
								END,
					MatchCode = CASE
									WHEN b.Product IN ('SB', 'CO') THEN m.matchcode
									ELSE ''
								END,
					EventDate = CASE
								WHEN b.Product IN ('SB', 'CO') THEN m.GlobalShowTime
								ELSE b.WinLostDate
							END,
					HomeId = CASE
								WHEN b.Product IN ('SB', 'CO') THEN m.homeid
								WHEN b.Product IN ('Outright') THEN o.teamid
								ELSE 0
							END,
					AwayId = CASE
								WHEN b.Product IN ('SB', 'CO') THEN m.awayid
								ELSE 0
							END,
					BetStatus = CASE
									WHEN b.Product IN ('SB', 'CO') THEN m.betstatus
									ELSE ''
								END,
					IsNeutral = CASE
									WHEN b.Product IN ('SB', 'CO') THEN ISNULL(m.IsNeutral, 0)
									ELSE 0
								END,
					BetCheck = CASE
									WHEN b.Product IN ('SB', 'CO') THEN ISNULL(b.betcheck, '')
									ELSE ''
								END,
					TransDesc = CASE
									WHEN b.Product IN ('SB', 'CO') THEN ISNULL(b.transdesc, '')
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
									WHEN b.Product IN ('SB', 'Outright') THEN ISNULL(b.ExtraInfo, '')
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
								END
				FROM #PagingData AS b
					LEFT JOIN bodb_Archive.dbo.match_bk AS m WITH (NOLOCK) ON b.Product IN ('SB', 'CO') AND b.matchid = m.matchid
					LEFT JOIN dbo.League AS le WITH (NOLOCK) ON b.Product IN ('SB') AND le.leagueid = m.leagueid
					LEFT JOIN bodb_Archive.dbo.outright_bk AS o WITH (NOLOCK) ON b.Product IN ('Outright') AND b.matchid = o.orid
					LEFT JOIN dbo.League AS l WITH (NOLOCK) ON b.Product IN ('Outright') AND o.leagueID = l.leagueID
				WHERE b.TableID = 3
			END
		END
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
		a.LeagueId,
		a.LeagueGroupId,
		a.MatchId,
		a.MatchCode,
		a.EventDate,
		a.HomeId,
		a.AwayId,
		a.IsNeutral,
		a.BetStatus,
		a.Currency,
		CAST(a.Stake * ISNULL(e.Rate, 1) AS DECIMAL(19, 8)) AS Stake,
		CAST(a.Actual_Stake * ISNULL(e.Rate, 1) AS DECIMAL(19, 8)) AS Actual_Stake,
		CAST(a.WinLost * ISNULL(e.Rate, 1) AS DECIMAL(19, 8)) AS WinLost,
		CAST(a.LicenseeWL * ISNULL(e.Rate, 1) AS DECIMAL(19, 8)) AS LicenseeWL,
		CAST(a.Comm * ISNULL(e.Rate, 1) AS DECIMAL(19, 8)) AS Comm,
		CAST(a.PlayerComm * ISNULL(e.Rate, 1) AS DECIMAL(19, 8)) AS PlayerComm,
		a.Ip,
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
		LEFT JOIN #ExchangeRate AS e ON a.WinLostDate BETWEEN e.FirstExchangeDateByMonth AND e.LastExchangeDateByMonth
	ORDER BY a.RowNum ASC

	SELECT DISTINCT * FROM @Detail

	DROP TABLE #PagingData
	DROP TABLE #ExchangeRate
END
