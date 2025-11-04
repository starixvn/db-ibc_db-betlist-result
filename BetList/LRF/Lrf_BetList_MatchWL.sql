/*<info serverAlias="DBEXT-bodb02" executers="wsv_lap" viewers="" isFunction="0" isNested="0"></info>*/

ALTER PROCEDURE [dbo].[Lrf_BetList_MatchWL]
	@AgentList		VARCHAR(MAX),
	@Date			SMALLDATETIME	= NULL,
	@MoveBetsDay	SMALLDATETIME,
	@ProductList	VARCHAR(500),
	@MatchId		INT,
	@EventType		TINYINT			= 1,
	@BetType		INT				= 0,
	@LiveIndicator	INT				= -1,
	@BaseCurrency	VARCHAR(12),
	@PageSize		INT				= 1000,
	@PageIndex		INT				= 1,
	@SortType		TINYINT			= 0,		-- TransDate
	@SortOrder		TINYINT			= 1,		-- ASC
	@TotalRows		INT				= 0 OUTPUT,
	@SumWinlost		MONEY			= 0 OUTPUT,
	@SumLicenseeWL	MONEY			= 0 OUTPUT,
	@SumComm		MONEY			= 0 OUTPUT,
	@SumPlayerComm	MONEY			= 0 OUTPUT
AS

/*
	Created: 20240129@Kos
	Task: LAP - Bet List of Match Win Loss Report - bettrans & bettrans14 range
	DB: DBEXT.bodb02
	Param's Explanation:
		- @SortType:
			- 0: TransDate
			- 1: Stake
			- 2: WinLoss
			- 3: LicenseeWL
		- @SortOrder
			- 1: ASC
			- 2: DESC

	Revisions:
		- 20240129@Kos: Merge VS1, VS2, VS3 into VS [Redmine: 199523]
		- 20240425@Kos: Return LeagueGroupId to support Jollysports [Redmine: #203258]
		- 20240906@Kos: Support Baseball AIO phase 2 [Redmine: 209344]
		- 20240919@Kos: Support BetRadar Horse Racing [Redmine: #210808]
		- 20241018@Kos: Hotfix - missing event info of BetRadar Horse Racing range bettrans14 [Redmine: #212397]
		- 20241028@Kos: Support Virtual Sports 6 [Redmine: 212446]
					- Add new input params @EventType TINYINT
		- 20250225@Kos: Fix bug FLOAT rounding [#Redmine: 194970]
		- 20250313@Kos: Remove BA [RedmineID: #216882]
					- Remove input param @ShowBA
		- 20250318@Kos: Support VS5 [Redmine: 207582]
		- 20250702@Kos: Fix security issue in dynamic query [#Redmine: 227496]
					- Remove input param @Sort
					- Add new input params @SortType TINYINT, @SortOrder TINYINT
		- 20251028@Kelvin: Integrate - Jacktime - Basketball Main Bettype Hybrid Parlay [#Redmine: 242357]
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

	-- Get group bettype
	DECLARE @GroupBetType TABLE (BetType INT, GroupTypeId INT)

	INSERT INTO @GroupBetType (BetType, GroupTypeId)
	SELECT
		bettype,
		GroupTypeId
	FROM dbo.Lrf_f_GroupBettype()

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

	INSERT INTO @SportBettype (ProductId, BetType, EventType)
	SELECT s.ProductID, s.BetType, s.EventType
	FROM dbo.f_SportBettypeMatrix_Sel (0, 0, 0, 2, '', @ProductList, @IsTest) AS s
	WHERE (@BetType = 0
			OR s.BetType = @BetType
			OR EXISTS (SELECT 1 FROM @GroupBetType WHERE GroupTypeId = @BetType AND BetType = s.BetType))
		AND s.BetType NOT IN (901, 902, 903, 904)
		AND s.BetType NOT BETWEEN 801 AND 899
		AND (s.EventType = @EventType OR @MatchId = 0)

	DECLARE @Match TABLE (MatchId INT)

	DECLARE
		@MatchSportType	SMALLINT,
		@ParentId		INT

	IF @MatchId <> 0
	BEGIN
		DELETE FROM @SportBettype
		WHERE EventType IN (0, 2)

		INSERT INTO @Match (MatchId)
		SELECT @MatchId

		IF @Date > @MoveBetsDay
		BEGIN
			SELECT
				@MatchSportType = m.sporttype,
				@ParentId = m.ParentID
			FROM dbo.match AS m WITH (NOLOCK)
			WHERE m.matchid = @MatchId AND m.eventdate > @MoveBetsDay
		END
		ELSE
		BEGIN
			SELECT
				@MatchSportType = m14.sporttype,
				@ParentId = m14.ParentID
			FROM dbo.match14 AS m14 WITH (NOLOCK)
			WHERE m14.matchid = @MatchId
		END

		IF @MatchSportType IN (8, 50) AND @ParentId IS NULL		-- Baseball, Cricket, parent match
		BEGIN
			IF @Date > @MoveBetsDay
			BEGIN
				INSERT INTO @Match (MatchId)
				SELECT DISTINCT m.MatchId
				FROM dbo.match AS m WITH (NOLOCK)
				WHERE m.ParentID = @MatchId
					AND m.sporttype = @MatchSportType
					AND m.eventdate = @Date
					AND m.ChildMatchType = 200
			END
			ELSE
			BEGIN
				INSERT INTO @Match (MatchId)
				SELECT DISTINCT m14.MatchId
				FROM dbo.match14 AS m14 WITH (NOLOCK)
				WHERE m14.ParentID = @MatchId
					AND m14.sporttype = @MatchSportType
					AND m14.eventdate = @Date
					AND m14.ChildMatchType = 200
			END
		END
	END

	CREATE TABLE #Data (
		TransId				BIGINT,
		RefNo				BIGINT,
		CustId				INT,
		Username			NVARCHAR(50),
		Nickname			VARCHAR(50),
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
		StatusId			TINYINT,
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
		Product				VARCHAR(30),
		EventType			TINYINT
	)

	CREATE TABLE #PagingData (
		RowNum				INT,
		TransId				BIGINT,
		RefNo				BIGINT,
		CustId				INT,
		Username			NVARCHAR(50),
		Nickname			VARCHAR(50),
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
		StatusId			TINYINT,
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
		Product				VARCHAR(30),
		EventType			TINYINT
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
		ExchangeId	INT,
		Rate		FLOAT
	)

	IF @HasError = 0
	BEGIN
		DECLARE @_Date	SMALLDATETIME

		SET @_Date = @Date

		IF @_Date > @MoveBetsDay
		BEGIN
			INSERT INTO #Data (
				TransId, RefNo, CustId, Currency, Recommend, BetType, BetId, BetTeam, Hdp1, Hdp2,
				OddsId, OddsType, Odds, MOdds, OddsSpread, Stake, Actual_Stake, AWinLost, WinLost, PlayerComm,
				Comm, Status, StatusId, TransDate, WinLostDate, LiveIndicator, LiveHomeScore, LiveAwayScore, Ip, MatchId,
				BetCheck, ComStatus, TransDesc, BetdaqId, ExtraInfo, WalletType, RefCode, Product, EventType
			)
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
				b.statusID,
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
				ISNULL(b.ExtraInfo, ''),
				b.WalletType,
				ISNULL(b.RefCode, 0),
				Product = CASE
								WHEN s.EventType = 0 AND s.ProductID = 1 THEN 'Parlay'		-- Sportsbook Parlay
								WHEN s.EventType = 0 AND s.ProductID = 3 THEN 'H5LG'		-- Happy 5 Linked Games (Number Game)
								WHEN s.EventType = 1 AND s.ProductID = 1 THEN 'SB'			-- Sportsbook
								WHEN s.EventType = 1 AND s.ProductID = 3 THEN 'NG'			-- Number Game
								WHEN s.EventType = 1 AND s.ProductID = 5 THEN 'VS'			-- Virtual Sports Sportsbook
								WHEN s.EventType = 2 AND s.ProductID = 1 THEN 'Outright'
								ELSE 'Unknown'
							END,
				s.EventType
			FROM dbo.bettrans AS b WITH (NOLOCK)
				INNER JOIN #TempAg AS ta ON ta.CustId = b.recommend
				INNER JOIN @SportBettype AS s ON s.BetType = b.bettype
			WHERE b.winlostdate = @_Date
				AND b.statusID IN (111, 112, 113)
				AND (@LiveIndicator = -1 OR b.Liveindicator = @LiveIndicator)
				AND (b.matchid IN (SELECT MatchId FROM @Match)
					OR EventType NOT IN (1, 3, 5))
		END
		ELSE
		BEGIN
			INSERT INTO #Data (
				TransId, RefNo, CustId, Currency, Recommend, BetType, BetId, BetTeam, Hdp1, Hdp2,
				OddsId, OddsType, Odds, MOdds, OddsSpread, Stake, Actual_Stake, AWinLost, WinLost, PlayerComm,
				Comm, Status, StatusId, TransDate, WinLostDate, LiveIndicator, LiveHomeScore, LiveAwayScore, Ip, MatchId,
				BetCheck, ComStatus, TransDesc, BetdaqId, ExtraInfo, WalletType, RefCode, Product, EventType
			)
			SELECT
				b14.transid,
				b14.refno,
				b14.custid,
				b14.currency,
				b14.recommend,
				b14.bettype,
				ISNULL(b14.BetId, 0) AS BetId,
				b14.betteam,
				b14.hdp1,
				b14.hdp2,
				b14.oddsid,
				b14.oddstype,
				b14.odds,
				b14.modds,
				b14.oddsspread,
				b14.stake,
				b14.actual_stake,
				b14.awinlost,
				b14.winlost,
				b14.playercomm,
				b14.comm,
				b14.status,
				b14.statusID,
				b14.transdate,
				b14.winlostdate,
				b14.liveindicator,
				b14.livehomescore,
				b14.liveawayscore,
				b14.ip,
				b14.matchid,
				b14.betcheck,
				b14.comstatus,
				b14.transdesc,
				b14.betdaqid,
				ISNULL(b14.ExtraInfo, ''),
				b14.WalletType,
				ISNULL(b14.RefCode, 0),
				Product = CASE
								WHEN s.EventType = 0 AND s.ProductID = 1 THEN 'Parlay'		-- Sportsbook Parlay
								WHEN s.EventType = 0 AND s.ProductID = 3 THEN 'H5LG'		-- Happy 5 Linked Games (Number Game)
								WHEN s.EventType = 1 AND s.ProductID = 1 THEN 'SB'			-- Sportsbook
								WHEN s.EventType = 1 AND s.ProductID = 3 THEN 'NG'			-- Number Game
								WHEN s.EventType = 1 AND s.ProductID = 5 THEN 'VS'			-- Virtual Sports Sportsbook
								WHEN s.EventType = 2 AND s.ProductID = 1 THEN 'Outright'
								WHEN s.EventType = 3 AND s.ProductID = 5 THEN 'VR'			-- Virtual Sports Racing
								ELSE 'Unknown'
							END,
				s.EventType
			FROM dbo.bettrans14 AS b14 WITH (NOLOCK)
				INNER JOIN #TempAg AS ta ON ta.CustId = b14.recommend
				INNER JOIN @SportBettype AS s ON s.BetType = b14.bettype
			WHERE b14.winlostdate = @_Date
				AND b14.statusID IN (111, 112, 113)
				AND (@LiveIndicator = -1 OR b14.Liveindicator = @LiveIndicator)
				AND (b14.matchid IN (SELECT MatchId FROM @Match)
					OR EventType NOT IN (1, 3, 5))
		END

		UPDATE b
		SET
			b.Username = c.username,
			b.Nickname = SUBSTRING(c.username2, CHARINDEX('$', c.username2) + 1, LEN(c.username2) - CHARINDEX('$', c.username2))
		FROM #Data AS b
			INNER JOIN dbo.Customer AS c (NOLOCK) ON c.custid = b.CustId

		IF EXISTS (SELECT TOP(1) 1 FROM #Data)
		BEGIN
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
				INSERT INTO @RefCodeTmp(
					RefCode,
					TransId,
					Stake,
					Actual_Stake,
					WinLost,
					LicenseeWL,
					Comm,
					PlayerComm
				)
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
			IF @BaseCurrency <> ''
			BEGIN
				INSERT INTO #ExchangeRate (ExchangeId, Rate)
				SELECT
					ExchangeId,
					Rate
				FROM dbo.Lrf_f_GetExchangeRate(@_Date, @_Date, @BaseCurrency, '')
			END

			-- Return data
			SELECT
				@TotalRows		= COUNT(b.TransId),
				@SumWinlost		= SUM(b.WinLost		* ISNULL(e.Rate, 1)),
				@SumLicenseeWL	= SUM(b.LicenseeWL	* ISNULL(e.Rate, 1)),
				@SumComm		= SUM(b.Comm		* ISNULL(e.Rate, 1)),
				@SumPlayerComm	= SUM(b.PlayerComm	* ISNULL(e.Rate, 1))
			FROM #Data AS b
				LEFT JOIN #ExchangeRate AS e ON e.ExchangeId = b.Currency

			DECLARE @SortText VARCHAR(100)

			-- Get sort text
			SET @SortText = CASE
								WHEN @SortType = 0 THEN 'TransDate'
								WHEN @SortType = 1 THEN 'Stake'
								WHEN @SortType = 2 THEN 'WinLost'
								WHEN @SortType = 3 THEN 'LicenseeWL'
								ELSE ''
							END

			IF @BaseCurrency <> '' AND @SortType IN (1, 2, 3)
			BEGIN
				SET @SortText = @SortText + ' * ISNULL(e.Rate, 1)'
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
						FROM #Data AS d' +
						CASE
							WHEN @SortText LIKE '%e.Rate%' THEN N'
							LEFT JOIN #ExchangeRate AS e ON e.ExchangeId = d.Currency'
							ELSE N' '
						END + N'
					) AS a
				WHERE a.RowNum BETWEEN @RowStart AND @RowEnd
				ORDER BY a.RowNum ASC'

			INSERT INTO #PagingData
			(
				RowNum, TransId, RefNo, CustId, Username, Nickname, Currency, Recommend, SportType, BetType,
				BetId, BetTeam, Hdp1, Hdp2, OddsId, OddsType, Odds, MOdds, OddsSpread, Stake,
				Actual_Stake, AWinLost, WinLost, LicenseeWL, PlayerComm, Comm, Status, StatusId, TransDate, WinLostDate,
				LiveIndicator, LiveHomeScore, LiveAwayScore, Ip, LeagueId, LeagueGroupId, MatchId, MatchCode, Race, EventDate,
				HomeId, AwayId, BetStatus, IsNeutral, Placing, ShowTime, BetCheck, ComStatus, TransDesc, BetdaqId,
				ExtraInfo, OriginalStake, OriginalBetType, WalletType, RefCode, SiteId, Product, EventType
			)
			EXEC sp_executesql @Sql, N'@RowStart INT, @RowEnd INT', @RowStart, @RowEnd;

			IF @_Date > @MoveBetsDay
			BEGIN
				UPDATE p
				SET
					TransId = CASE
								WHEN p.Product = 'Parlay' AND p.BetType = 29 AND ISNULL(p.BetId, 0) > 0 THEN p.BetId
								ELSE p.TransId
							END,
					SportType = CASE
									WHEN p.EventType = 1 THEN m.sporttype
									WHEN p.EventType = 5 THEN m3rd.SportType
									WHEN p.Product IN ('H5LG') THEN p.MatchId
									WHEN p.Product IN ('Outright') THEN l.sporttype
									WHEN p.EventType = 3 THEN vr.SportType
									ELSE 0
								END,
					LiveIndicator = CASE
										WHEN p.EventType IN (1, 5) THEN p.liveindicator
										ELSE 0
									END,
					LiveAwayScore = CASE
										WHEN p.EventType IN (1, 5) THEN p.liveawayscore
										WHEN p.Product IN ('Outright') THEN p.liveawayscore
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
					MatchId = CASE
									WHEN p.EventType IN (1, 3, 5) THEN p.matchid
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
									WHEN p.Product IN ('SB') THEN ISNULL(p.betcheck, '')
									WHEN p.EventType = 0 THEN ISNULL(p.betcheck, '')
									ELSE ''
								END,
					TransDesc = CASE
									WHEN p.EventType IN (1, 3, 5) THEN ISNULL(p.transdesc, '')
									WHEN p.Product IN ('H5LG') THEN ISNULL(p.transdesc, '')
									WHEN p.Product = 'Parlay' AND p.OddsSpread = 3 THEN ISNULL(p.transdesc, '')
									ELSE ''
								END,
					OddsSpread = CASE
									WHEN p.Product IN ('SB') THEN ISNULL(p.oddsspread, 0)
									ELSE 0
								END,
					BetdaqId = CASE
									WHEN p.Product IN ('SB') THEN ISNULL(p.betdaqid, -1)
									ELSE -1
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
								END,
					SiteId = CASE
									WHEN p.Product IN ('H5LG') THEN CONVERT(VARCHAR(20), p.BetdaqId)
									ELSE ''
								END
				FROM #PagingData AS p
					LEFT JOIN dbo.match AS m WITH (NOLOCK) ON p.EventType = 1 AND p.matchid = m.matchid
					LEFT JOIN dbo.League AS le WITH (NOLOCK) ON p.Product IN ('SB') AND le.leagueid = m.leagueid
					LEFT JOIN dbo.outright AS o WITH (NOLOCK) ON p.Product IN ('Outright') AND p.matchid = o.orid
					LEFT JOIN dbo.League AS l WITH (NOLOCK) ON p.Product IN ('Outright') AND o.leagueID = l.leagueID
					LEFT JOIN dbo.VSRaceInfo AS vr WITH(NOLOCK) ON p.EventType = 3 AND vr.EventID = p.matchid
					LEFT JOIN dbo.Match3rd AS m3rd WITH (NOLOCK) ON p.EventType = 5 AND m3rd.Match3rdId = p.matchid
			END
			ELSE
			BEGIN
				UPDATE p14
				SET
					TransId = CASE
								WHEN p14.Product = 'Parlay' AND p14.BetType = 29 AND ISNULL(p14.BetId, 0) > 0 THEN p14.BetId
								ELSE p14.TransId
							END,
					SportType = CASE
									WHEN p14.EventType = 1 THEN m.sporttype
									WHEN p14.EventType = 5 THEN m3rd.SportType
									WHEN p14.Product IN ('H5LG') THEN p14.MatchId
									WHEN p14.Product IN ('Outright') THEN l.sporttype
									WHEN p14.EventType = 3 THEN vr.SportType
									ELSE 0
								END,
					LiveIndicator = CASE
										WHEN p14.EventType IN (1, 5) THEN p14.liveindicator
										ELSE 0
									END,
					LiveAwayScore = CASE
										WHEN p14.EventType IN (1, 5) THEN p14.liveawayscore
										WHEN p14.Product IN ('Outright') THEN p14.liveawayscore
										ELSE 0
									END,
					LeagueId = CASE
									WHEN p14.EventType = 1 THEN m.leagueid
									WHEN p14.EventType = 5 THEN m3rd.League3rdId
									WHEN p14.Product IN ('Outright') THEN o.leagueid
									WHEN p14.EventType = 3 THEN vr.LeagueID
									ELSE 0
								END,
					LeagueGroupId = CASE
										WHEN p14.Product IN ('SB') THEN le.LeagueGroupID
										ELSE 0
									END,
					MatchId = CASE
									WHEN p14.EventType IN (1, 3, 5) THEN p14.matchid
									ELSE 0
								END,
					MatchCode = CASE
									WHEN p14.EventType = 1 THEN m.matchcode
									WHEN p14.Product IN ('Outright') THEN o.matchcode
									ELSE ''
								END,
					Race = CASE
								WHEN p14.Product IN ('Outright') THEN o.groupmatch
								ELSE ''
							END,
					EventDate = CASE
								WHEN p14.Product IN ('SB') THEN m.GlobalShowTime
								ELSE p14.WinLostDate
							END,
					HomeId = CASE
								WHEN p14.EventType = 1 THEN m.homeid
								WHEN p14.EventType = 5 THEN m3rd.HomeId
								WHEN p14.Product IN ('Outright') THEN o.teamid
								ELSE 0
							END,
					AwayId = CASE
								WHEN p14.EventType = 1 THEN m.awayid
								WHEN p14.EventType = 5 THEN m3rd.AwayId
								ELSE 0
							END,
					BetStatus = CASE
									WHEN p14.EventType = 1 THEN m.betstatus
									ELSE ''
								END,
					IsNeutral = CASE
									WHEN p14.EventType = 1 THEN ISNULL(m.IsNeutral, 0)
									ELSE 0
								END,
					Placing = '',
					ShowTime = CASE
									WHEN p14.Product IN ('VS') THEN CONVERT(NVARCHAR(50), m.kickofftime)
									WHEN p14.EventType = 5 THEN CONVERT(NVARCHAR(50), m3rd.StartTime)
									ELSE ''
								END,
					BetCheck = CASE
									WHEN p14.Product IN ('SB') THEN ISNULL(p14.betcheck, '')
									WHEN p14.EventType = 0 THEN ISNULL(p14.betcheck, '')
									ELSE ''
								END,
					TransDesc = CASE
									WHEN p14.EventType IN (1, 3, 5) THEN ISNULL(p14.transdesc, '')
									WHEN p14.Product IN ('H5LG') THEN ISNULL(p14.transdesc, '')
									WHEN p14.Product = 'Parlay' AND p14.OddsSpread = 3 THEN ISNULL(p14.transdesc, '')
									ELSE ''
								END,
					OddsSpread = CASE
									WHEN p14.Product IN ('SB') THEN ISNULL(p14.oddsspread, 0)
									ELSE 0
								END,
					BetdaqId = CASE
									WHEN p14.Product IN ('SB') THEN ISNULL(p14.betdaqid, -1)
									ELSE -1
								END,
					OriginalStake = 0,
					OriginalBetType = CASE
										WHEN p14.Product IN ('SB') AND p14.stake <> 0 THEN -1
										ELSE 0
									END,
					WalletType = CASE
									WHEN p14.Product IN ('SB') THEN ISNULL(p14.WalletType, 0)
									ELSE 0
								END,
					RefCode = CASE
									WHEN p14.Product IN ('SB') AND p14.stake <> 0 THEN ISNULL(p14.RefCode, 0)
									ELSE 0
								END,
					SiteId = CASE
									WHEN p14.Product IN ('H5LG') THEN CONVERT(VARCHAR(20), p14.BetdaqId)
									ELSE ''
								END
				FROM #PagingData AS p14
					LEFT JOIN dbo.match14 AS m WITH (NOLOCK) ON p14.EventType = 1 AND p14.matchid = m.matchid
					LEFT JOIN dbo.League AS le WITH (NOLOCK) ON p14.Product IN ('SB') AND le.leagueid = m.leagueid
					LEFT JOIN dbo.outright14 AS o WITH (NOLOCK) ON p14.Product IN ('Outright') AND p14.matchid = o.orid
					LEFT JOIN dbo.League AS l WITH (NOLOCK) ON p14.Product IN ('Outright') AND o.leagueID = l.leagueID
					LEFT JOIN dbo.VSRaceInfo14 AS vr WITH(NOLOCK) ON p14.EventType = 3 AND vr.EventID = p14.matchid
					LEFT JOIN dbo.Match3rd14 AS m3rd WITH (NOLOCK) ON p14.EventType = 5 AND m3rd.Match3rdId = p14.matchid
			END
		END
	END

	-- Return data
	SELECT
		a.Username,
		a.Nickname,
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
		a.LiveIndicator,
		a.LiveHomeScore,
		a.LiveAwayScore,
		a.Race,
		a.LeagueId,
		a.LeagueGroupId,
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
		a.SiteId,
		a.RefCode
	FROM
		#PagingData AS a
		LEFT JOIN #ExchangeRate AS e ON e.ExchangeId = a.Currency
	ORDER BY a.RowNum ASC

	SELECT DISTINCT
		RefNo,
		Odds,
		Stake,
		Status,
		APositionTaking,
		BetType,
		BetTeam
	FROM @Detail

	DROP TABLE #TempAg
	DROP TABLE #Data
	DROP TABLE #PagingData
	DROP TABLE #ExchangeRate
END
GO
