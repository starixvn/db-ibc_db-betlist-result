/*<info serverAlias="DBEXT-bodb02" executers="wsv_lap" viewers="" isFunction="0" isNested="0"></info>*/

ALTER PROCEDURE [dbo].[Lrf_BetList_MatchWL]
	@AgentList		VARCHAR(MAX),
	@Date			SMALLDATETIME	= NULL,
	@MoveBetsDay	SMALLDATETIME,
	@ProductList	VARCHAR(500),
	@ShowBA			BIT				= 0,
	@MatchId		INT,
	@BetType		INT				= 0,
	@LiveIndicator	INT				= -1,
	@BaseCurrency	VARCHAR(12),
	@PageSize		INT				= 1000,
	@PageIndex		INT				= 1,
	@Sort			NVARCHAR(50)	= N'TransDate ASC',
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

	Revisions:
		- 20240129@Kos: Merge VS1, VS2, VS3 into VS [Redmine: 199523]
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

	INSERT INTO @GroupBetType
	SELECT
		bettype,
		GroupTypeId
	FROM dbo.Lrf_f_GroupBettype()

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
	SELECT s.ProductID, s.BetType, s.EventType
	FROM dbo.f_SportBettypeMatrix_Sel (0, 0, 0, 2, '', @ProductList, @IsTest) AS s
	WHERE (@BetType = 0
			OR s.BetType = @BetType
			OR EXISTS (SELECT 1 FROM @GroupBetType WHERE GroupTypeId = @BetType AND BetType = s.BetType))
		AND s.BetType NOT IN (901, 902, 903, 904)
		AND s.BetType NOT BETWEEN 801 AND 899

	IF @MatchId <> 0
	BEGIN
		DELETE FROM @SportBettype
		WHERE EventType IN (0, 2)
	END

	CREATE TABLE #Data (
		TransId				BIGINT,
		RefNo				BIGINT,
		BATransId			BIGINT,
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
		BATransId			BIGINT,
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
				StatusId,
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
				Product,
				EventType,
				BATransId)
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
								WHEN s.EventType = 3 AND s.ProductID = 5 THEN 'VR'			-- Virtual Sports Racing
								ELSE 'Unknown'
							END,
				s.EventType,
				ba.TransID
			FROM dbo.bettrans AS b WITH (NOLOCK)
				INNER JOIN #TempAg AS ta ON ta.CustId = b.recommend
				INNER JOIN @SportBettype AS s ON s.BetType = b.bettype
				LEFT JOIN bodb_Licensee.dbo.LicenseeBATransaction_active AS ba WITH (NOLOCK) ON b.transid = ba.TransID
			WHERE b.winlostdate = @_Date
				AND b.statusID IN (111, 112, 113)
				AND (@LiveIndicator = -1 OR b.Liveindicator = @LiveIndicator)
				AND (b.matchid = @MatchId OR EventType NOT IN (1, 3))
		END
		ELSE
		BEGIN
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
				StatusId,
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
				Product,
				EventType,
				BATransId)
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
								WHEN s.EventType = 3 AND s.ProductID = 5 THEN 'VR'			-- Virtual Sports Racing
								ELSE 'Unknown'
							END,
				s.EventType,
				ba.TransID
			FROM dbo.bettrans14 AS b WITH (NOLOCK)
				INNER JOIN #TempAg AS ta ON ta.CustId = b.recommend
				INNER JOIN @SportBettype AS s ON s.BetType = b.bettype
				LEFT JOIN bodb_Licensee.dbo.LicenseeBATransaction_bk AS ba WITH (NOLOCK) ON b.transid = ba.TransID
			WHERE b.winlostdate = @_Date
				AND b.statusID IN (111, 112, 113)
				AND (@LiveIndicator = -1 OR b.Liveindicator = @LiveIndicator)
				AND (b.matchid = @MatchId OR EventType NOT IN (1, 3))
		END

		DELETE #Data
		WHERE (@ShowSB = 0
				AND Product IN ('SB', 'Parlay', 'Outright')
				AND BATransId IS NULL)
			OR (@ShowBA = 0
				AND Product IN ('SB', 'Parlay', 'Outright')
				AND BATransId IS NOT NULL)

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
			IF @BaseCurrency <> ''
			BEGIN
				INSERT INTO #ExchangeRate
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

			-- Get sort text
			IF @BaseCurrency <> ''
				AND (@Sort LIKE '%Stake%' OR @Sort LIKE '%WinLost%' OR @Sort LIKE '%LicenseeWL%')
			BEGIN
				DECLARE @CharIndex TINYINT

				SELECT @CharIndex = CHARINDEX(' ', @Sort, 1)

				SELECT @Sort = SUBSTRING(@Sort, 0, @CharIndex) + ' * ISNULL(e.Rate, 1)' + SUBSTRING(@Sort, @CharIndex, LEN(@Sort))
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
							ROW_NUMBER() OVER (ORDER BY ' + @Sort + N') AS RowNum,
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

			IF @_Date > @MoveBetsDay
			BEGIN
				UPDATE b
				SET
					TransId = CASE
								WHEN b.Product = 'Parlay' AND b.BetType = 29 AND ISNULL(b.BetId, 0) > 0 THEN b.BetId
								ELSE b.TransId
							END,
					SportType = CASE
									WHEN b.EventType = 1 THEN m.sporttype
									WHEN b.Product IN ('H5LG') THEN b.MatchId
									WHEN b.Product IN ('Outright') THEN l.sporttype
									WHEN b.Product IN ('VR') THEN vr.SportType
									ELSE 0
								END,
					OddsType = CASE
									WHEN b.EventType = 1 THEN b.OddsType
									WHEN b.Product IN ('Outright', 'VR') THEN b.OddsType
									ELSE 0
								END,
					LiveIndicator = CASE
										WHEN b.EventType = 1 THEN b.liveindicator
										ELSE 0
									END,
					LiveAwayScore = CASE
										WHEN b.EventType = 1 THEN b.liveawayscore
										WHEN b.Product IN ('Outright', 'VR') THEN b.liveawayscore
										ELSE 0
									END,
					LeagueId = CASE
									WHEN b.EventType = 1 THEN m.leagueid
									WHEN b.Product IN ('Outright') THEN o.leagueid
									WHEN b.Product IN ('VR') THEN vr.LeagueID
									ELSE 0
								END,
					MatchId = CASE
									WHEN b.EventType = 1 THEN m.matchid
									WHEN b.Product IN ('VR') THEN b.matchid
									ELSE 0
								END,
					MatchCode = CASE
									WHEN b.EventType = 1 THEN m.matchcode
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
								WHEN b.EventType = 1 THEN m.homeid
								WHEN b.Product IN ('Outright') THEN o.teamid
								WHEN b.Product IN ('VR') THEN vo.RacerID
								ELSE 0
							END,
					AwayId = CASE
								WHEN b.EventType = 1 THEN m.awayid
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
					Placing = CASE
									WHEN b.Product IN ('VR') THEN CONVERT(VARCHAR(5), vo.Placing)
									ELSE ''
								END,
					ShowTime = CASE
									WHEN b.Product IN ('VS') THEN CONVERT(NVARCHAR(50), m.kickofftime)
									WHEN b.Product IN ('VR') THEN CONVERT(NVARCHAR(50), vr.EventTime)
									ELSE ''
								END,
					BetCheck = CASE
									WHEN b.Product IN ('SB') THEN ISNULL(b.betcheck, '')
									WHEN b.EventType = 0 THEN ISNULL(b.betcheck, '')
									ELSE ''
								END,
					TransDesc = CASE
									WHEN b.EventType = 1 THEN ISNULL(b.transdesc, '')
									WHEN b.Product IN ('H5LG') THEN ISNULL(b.transdesc, '')
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
								END,
					SiteId = CASE
									WHEN b.Product IN ('H5LG') THEN CONVERT(VARCHAR(20), b.BetdaqId)
									ELSE ''
								END
				FROM #PagingData AS b
					LEFT JOIN dbo.match AS m WITH (NOLOCK) ON b.EventType = 1 AND b.matchid = m.matchid
					LEFT JOIN dbo.outright AS o WITH (NOLOCK) ON b.Product IN ('Outright') AND b.matchid = o.orid
					LEFT JOIN dbo.League AS l WITH (NOLOCK) ON b.Product IN ('Outright') AND o.leagueID = l.leagueID
					LEFT JOIN dbo.VSOutright AS vo WITH (NOLOCK) ON b.Product IN ('VR') AND b.oddsid = vo.Orid
					LEFT JOIN dbo.VSRaceInfo AS vr WITH(NOLOCK) ON b.Product IN ('VR') AND vr.EventID = vo.EventID
			END
			ELSE
			BEGIN
				UPDATE b
				SET
					TransId = CASE
								WHEN b.Product = 'Parlay' AND b.BetType = 29 AND ISNULL(b.BetId, 0) > 0 THEN b.BetId
								ELSE b.TransId
							END,
					SportType = CASE
									WHEN b.EventType = 1 THEN m.sporttype
									WHEN b.Product IN ('H5LG') THEN b.MatchId
									WHEN b.Product IN ('Outright') THEN l.sporttype
									WHEN b.Product IN ('VR') THEN vr.SportType
									ELSE 0
								END,
					OddsType = CASE
									WHEN b.EventType = 1 THEN b.OddsType
									WHEN b.Product IN ('Outright', 'VR') THEN b.OddsType
									ELSE 0
								END,
					LiveIndicator = CASE
										WHEN b.EventType = 1 THEN b.liveindicator
										ELSE 0
									END,
					LiveAwayScore = CASE
										WHEN b.EventType = 1 THEN b.liveawayscore
										WHEN b.Product IN ('Outright', 'VR') THEN b.liveawayscore
										ELSE 0
									END,
					LeagueId = CASE
									WHEN b.EventType = 1 THEN m.leagueid
									WHEN b.Product IN ('Outright') THEN o.leagueid
									WHEN b.Product IN ('VR') THEN vr.LeagueID
									ELSE 0
								END,
					MatchId = CASE
									WHEN b.EventType = 1 THEN m.matchid
									WHEN b.Product IN ('VR') THEN b.matchid
									ELSE 0
								END,
					MatchCode = CASE
									WHEN b.EventType = 1 THEN m.matchcode
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
								WHEN b.EventType = 1 THEN m.homeid
								WHEN b.Product IN ('Outright') THEN o.teamid
								WHEN b.Product IN ('VR') THEN vo.RacerID
								ELSE 0
							END,
					AwayId = CASE
								WHEN b.EventType = 1 THEN m.awayid
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
					Placing = CASE
									WHEN b.Product IN ('VR') THEN CONVERT(VARCHAR(5), vo.Placing)
									ELSE ''
								END,
					ShowTime = CASE
									WHEN b.Product IN ('VS') THEN CONVERT(NVARCHAR(50), m.kickofftime)
									WHEN b.Product IN ('VR') THEN CONVERT(NVARCHAR(50), vr.EventTime)
									ELSE ''
								END,
					BetCheck = CASE
									WHEN b.Product IN ('SB') THEN ISNULL(b.betcheck, '')
									WHEN b.EventType = 0 THEN ISNULL(b.betcheck, '')
									ELSE ''
								END,
					TransDesc = CASE
									WHEN b.EventType = 1 THEN ISNULL(b.transdesc, '')
									WHEN b.Product IN ('H5LG') THEN ISNULL(b.transdesc, '')
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
								END,
					SiteId = CASE
									WHEN b.Product IN ('H5LG') THEN CONVERT(VARCHAR(20), b.BetdaqId)
									ELSE ''
								END
				FROM #PagingData AS b
					LEFT JOIN dbo.match14 AS m WITH (NOLOCK) ON b.EventType = 1 AND b.matchid = m.matchid
					LEFT JOIN dbo.outright14 AS o WITH (NOLOCK) ON b.Product IN ('Outright') AND b.matchid = o.orid
					LEFT JOIN dbo.League AS l WITH (NOLOCK) ON b.Product IN ('Outright') AND o.leagueID = l.leagueID
					LEFT JOIN dbo.VSOutright14 AS vo WITH (NOLOCK) ON b.Product IN ('VR') AND b.oddsid = vo.Orid
					LEFT JOIN dbo.VSRaceInfo AS vr WITH(NOLOCK) ON b.Product IN ('VR') AND vr.EventID = vo.EventID
			END
		END
	END

	-- Get ticket detail
	-- Virtual Sports
	IF EXISTS (SELECT 1 FROM #PagingData WHERE Product = 'VR')
	BEGIN
		IF @_Date > @MoveBetsDay
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
		ELSE
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
			FROM dbo.bettransm14 AS bm WITH (NOLOCK)
				INNER JOIN #PagingData AS b ON bm.refno = b.RefNo AND bm.custid = b.CustId
				INNER JOIN dbo.SportBettypeMatrix AS sbt WITH (NOLOCK) ON bm.bettype = sbt.Bettype
				LEFT JOIN #ExchangeRate AS e ON e.ExchangeId = b.Currency
			WHERE b.Product = 'VR'
				AND sbt.ProductID = 5
				AND sbt.EventType = 3
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
		a.SiteId,
		a.RefCode
	FROM
		#PagingData AS a
		LEFT JOIN #ExchangeRate AS e ON e.ExchangeId = a.Currency
	ORDER BY a.RowNum ASC

	SELECT DISTINCT * FROM @Detail

	DROP TABLE #TempAg
	DROP TABLE #Data
	DROP TABLE #PagingData
	DROP TABLE #ExchangeRate
END
GO
