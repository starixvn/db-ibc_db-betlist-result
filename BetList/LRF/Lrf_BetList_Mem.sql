/*<info serverAlias="DBACC-bodb02" executers="bodbLicenseeNet" viewers="vnteam" isFunction="0" isNested="0"></info>*/

ALTER PROCEDURE [dbo].[Lrf_BetList_Mem]
	@AgentList		VARCHAR(MAX),
	@CustId			INT				= 0,
	@Username		VARCHAR(50)		= '',
	@FromDate		SMALLDATETIME,
	@ToDate			SMALLDATETIME,
	@MoveBetsDay	SMALLDATETIME,
	@BalanceUpDay	SMALLDATETIME,
	@BaseCurrency	VARCHAR(10)		= '',
	@StatusIdList	VARCHAR(50)		= '',
	@Platform		TINYINT			= 0,
	@LiveIndicator	TINYINT			= 2,
	@PageSize		INT				= 1000,
	@PageIndex		INT				= 1,
	@Sort			NVARCHAR(50)	= N'Transid ASC',
	@ProductList	VARCHAR(200)	= '',
	@ShowBA			BIT				= 0,	-- BA
	@TotalRows		INT				= 0 OUTPUT,
	@SumStake		MONEY			= 0 OUTPUT,
	@SumWinLost		MONEY			= 0 OUTPUT,
	@SumLicenseeWL	MONEY			= 0 OUTPUT,
	@SumComm		MONEY			= 0 OUTPUT,
	@SumPlayerComm	MONEY			= 0 OUTPUT
AS

/*
	Created: Kos@20180613
	Task: Betting Ticket Center - Single Customer Bet List
	DB: DBACC.bodb02
	Parameter's Explanation:
		- @Status: '111,112,113,101,102,103'
		- @Platform:
			- 0 - All: All
			- 1 - Asia: d (mobile), g (MG Download only)
			- 2 - China: a (dep-Singbet), z (dep2-SingBet)
			- 3 - Euro: e (Europe), u (dep-Euro), y (dep2-Euro)
			- 4 - WAP: m (dep-wap)
			- 5 - Smart Site: s (smartphone), l (dep-smart)
			- 6 - Tablet: r (dep2-tablet)
			 -7 - New Asia: x (dep2-Asia)
		- @LiveIndicator:
			- 0 : Non-live
			- 1 : Live
			- 2 : Mix Non Live & Live (Parlay only)
			- 3 : All

	Revisions:
		- 20180711@Kos: Created [#Redmine: 80941]
		- 20181102@Kos: Remove DBLIC linked server [#Redmine: 103660]
		- 20181113@Kos: Support new platform Mobile App [#Redmine: 104521]
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

	IF @HasError = 0
	BEGIN
		-- Get CustId in case of inputting Username
		IF @CustId = 0 AND @Username <> ''
		BEGIN
			SET @CustId = -1

			SELECT @CustId = custid
			FROM dbo.Customer AS c WITH (NOLOCK)
			WHERE EXISTS (SELECT 1 FROM @TempAg WHERE CustId = c.recommend)
				AND c.username = @Username

			IF @CustId = -1
			BEGIN
				SELECT @CustId = custid
				FROM dbo.Customer AS c WITH (NOLOCK)
				WHERE EXISTS (SELECT 1 FROM @TempAg WHERE CustId = c.recommend)
					AND c.username2 LIKE + '%$' + @Username
			END
		END

		IF @CustId <> 0
			AND NOT EXISTS (	SELECT 1 FROM dbo.custInfo AS c WITH (NOLOCK)
								WHERE c.custid = @CustId
									AND EXISTS (	SELECT 1 FROM @TempAg
													WHERE CustId = c.recommend AND Currency = c.currency))
		BEGIN
			SET @HasError = 1
		END
	END

	CREATE TABLE #Data (
		TransId			BIGINT,
		RefNo			BIGINT,
		BATransId		BIGINT,
		CustId			INT,
		Currency		SMALLINT,
		SportType		SMALLINT,
		BetType			SMALLINT,
		BetId			BIGINT,
		BetTeam			NVARCHAR(20),
		Hdp1			SMALLMONEY,
		Hdp2			SMALLMONEY,
		OddsType		TINYINT,
		Odds			MONEY,
		MOdds			MONEY,
		OddsSpread		MONEY,
		Stake			MONEY,
		Actual_Stake	MONEY,
		WinLost			MONEY,
		LicenseeWL		MONEY,
		Comm			MONEY,
		PlayerComm		MONEY,
		Status			NVARCHAR(10),
		TransDate		DATETIME,
		WinLostDate		SMALLDATETIME,
		LiveIndicator	BIT,
		LiveHomeScore	SMALLINT,
		LiveAwayScore	SMALLINT,
		Ip				NVARCHAR(15),
		BetFrom			NVARCHAR(1),
		LeagueId		INT,
		MatchId			INT,
		MatchCode		NVARCHAR(50),
		Race			NVARCHAR(50),
		HomeId			INT,
		AwayId			INT,
		BetStatus		NVARCHAR(50),
		IsNeutral		BIT,
		ShowTime		NVARCHAR(50),
		BetCheck		NVARCHAR(50),
		TransDesc		NVARCHAR(1000),
		BetdaqId		BIGINT,
		ExtraInfo		VARCHAR(1000),
		OriginalStake	MONEY,
		OriginalBetType	SMALLINT,
		WalletType		TINYINT,
		RefCode			BIGINT,
		ProductId		TINYINT,
		EventType		INT,
		SubProduct		VARCHAR(500),
		WhTicket		TINYINT
	)

	CREATE TABLE #PagingData (
		RowNum			INT,
		TransId			BIGINT,
		RefNo			BIGINT,
		BATransId		BIGINT,
		CustId			INT,
		Currency		SMALLINT,
		SportType		SMALLINT,
		BetType			SMALLINT,
		BetId			BIGINT,
		BetTeam			NVARCHAR(20),
		Hdp1			SMALLMONEY,
		Hdp2			SMALLMONEY,
		OddsType		TINYINT,
		Odds			MONEY,
		MOdds			MONEY,
		OddsSpread		MONEY,
		Stake			MONEY,
		Actual_Stake	MONEY,
		WinLost			MONEY,
		LicenseeWL		MONEY,
		Comm			MONEY,
		PlayerComm		MONEY,
		Status			NVARCHAR(10),
		TransDate		DATETIME,
		WinLostDate		SMALLDATETIME,
		LiveIndicator	BIT,
		LiveHomeScore	SMALLINT,
		LiveAwayScore	SMALLINT,
		Ip				NVARCHAR(15),
		BetFrom			NVARCHAR(1),
		LeagueId		INT,
		MatchId			INT,
		MatchCode		NVARCHAR(50),
		Race			NVARCHAR(50),
		HomeId			INT,
		AwayId			INT,
		BetStatus		NVARCHAR(50),
		IsNeutral		BIT,
		ShowTime		NVARCHAR(50),
		BetCheck		NVARCHAR(50),
		TransDesc		NVARCHAR(1000),
		BetdaqId		BIGINT,
		ExtraInfo		VARCHAR(1000),
		OriginalStake	MONEY,
		OriginalBetType	SMALLINT,
		WalletType		TINYINT,
		RefCode			BIGINT,
		ProductId		TINYINT,
		EventType		INT,
		SubProduct		VARCHAR(500),
		WhTicket		TINYINT
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

	DECLARE @Currency	INT,
		@Nickname		NVARCHAR(50)

	IF @HasError = 0
	BEGIN
		DECLARE @BetFromList VARCHAR(50)

		IF @Platform = 1
		BEGIN
			SET @BetFromList = 'd,g'
		END
		ELSE IF @Platform = 2
		BEGIN
			SET @BetFromList = 'a,z'
		END
		ELSE IF @Platform = 3
		BEGIN
			SET @BetFromList = 'e,u,y'
		END
		ELSE IF @Platform = 4
		BEGIN
			SET @BetFromList = 'm'
		END
		ELSE IF @Platform = 5
		BEGIN
			SET @BetFromList = 's,l'
		END
		ELSE IF @Platform = 6
		BEGIN
			SET @BetFromList = 'r'
		END
		ELSE IF @Platform = 7
		BEGIN
			SET @BetFromList = 'x'
		END
		ELSE IF @Platform = 8
		BEGIN
			SET @BetFromList = 'o'
		END

		DECLARE @TempToDate	SMALLDATETIME,
			@TempFromDate	SMALLDATETIME

		-- bettrans
		IF @ToDate > @MoveBetsDay
		BEGIN
			IF @FromDate <= @MoveBetsDay
				SET @TempFromDate = DATEADD(DAY, 1, @MoveBetsDay)
			ELSE
				SET @TempFromDate = @FromDate

			INSERT INTO #Data (
				TransId,
				RefNo,
				CustId,
				Currency,
				BetType,
				BetId,
				BetTeam,
				Hdp1,
				Hdp2,
				OddsType,
				Odds,
				MOdds,
				OddsSpread,
				Stake,
				Actual_Stake,
				WinLost,
				Comm,
				PlayerComm,
				Status,
				TransDate,
				WinLostDate,
				LiveIndicator,
				LiveHomeScore,
				LiveAwayScore,
				Ip,
				BetFrom,
				MatchId,
				BetCheck,
				TransDesc,
				BetdaqId,
				ExtraInfo,
				WalletType,
				RefCode,
				WhTicket)
			SELECT
				b.transid,
				b.refno,
				b.custid,
				b.currency,
				b.bettype,
				b.betid,
				b.betteam,
				b.hdp1,
				b.hdp2,
				b.oddstype,
				b.odds,
				b.modds,
				b.oddsspread,
				b.stake,
				b.actual_stake,
				b.winlost,
				b.comm,
				b.playercomm,
				b.status,
				b.transdate,
				b.winlostdate,
				b.liveindicator,
				b.livehomescore,
				b.liveawayscore,
				b.ip,
				b.betfrom,
				b.matchid,
				b.betcheck,
				b.transdesc,
				b.betdaqid,
				b.ExtraInfo,
				b.WalletType,
				ISNULL(b.RefCode, 0),
				1 AS WhTicket
			FROM dbo.bettrans AS b WITH (NOLOCK)
			WHERE b.custid = @CustId
				AND b.winlostdate BETWEEN @TempFromDate AND @ToDate
				AND ',' + @StatusIdList + ',' LIKE '%,' + CONVERT(VARCHAR(3), b.statusID) + ',%'
				AND (@Platform = 0
					OR ',' + @BetFromList + ',' LIKE '%,' + b.betfrom + ',%')
				AND (@LiveIndicator = 3
					OR (b.bettype IN (9, 29) AND b.livehomescore = @LiveIndicator)
					OR (b.bettype NOT IN (9, 29) AND b.liveindicator = @LiveIndicator))
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
				BetType,
				BetId,
				BetTeam,
				Hdp1,
				Hdp2,
				OddsType,
				Odds,
				MOdds,
				OddsSpread,
				Stake,
				Actual_Stake,
				WinLost,
				Comm,
				PlayerComm,
				Status,
				TransDate,
				WinLostDate,
				LiveIndicator,
				LiveHomeScore,
				LiveAwayScore,
				Ip,
				BetFrom,
				MatchId,
				BetCheck,
				TransDesc,
				BetdaqId,
				ExtraInfo,
				WalletType,
				RefCode,
				WhTicket)
			SELECT
				b.transid,
				b.refno,
				b.custid,
				b.currency,
				b.bettype,
				b.betid,
				b.betteam,
				b.hdp1,
				b.hdp2,
				b.oddstype,
				b.odds,
				b.modds,
				b.oddsspread,
				b.stake,
				b.actual_stake,
				b.winlost,
				b.comm,
				b.playercomm,
				b.status,
				b.transdate,
				b.winlostdate,
				b.liveindicator,
				b.livehomescore,
				b.liveawayscore,
				b.ip,
				b.betfrom,
				b.matchid,
				b.betcheck,
				b.transdesc,
				b.betdaqid,
				b.ExtraInfo,
				b.WalletType,
				ISNULL(b.RefCode, 0),
				2 AS WhTicket
			FROM dbo.bettrans14 AS b WITH (NOLOCK)
			WHERE b.custid = @CustId
				AND b.winlostdate BETWEEN @TempFromDate AND @TempToDate
				AND ',' + @StatusIdList + ',' LIKE '%,' + CONVERT(VARCHAR(3), b.statusID) + ',%'
				AND (@Platform = 0
					OR ',' + @BetFromList + ',' LIKE '%,' + b.betfrom + ',%')
				AND (@LiveIndicator = 3
					OR (b.bettype IN (9, 29) AND b.livehomescore = @LiveIndicator)
					OR (b.bettype NOT IN (9, 29) AND b.liveindicator = @LiveIndicator))
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
				BetType,
				BetId,
				BetTeam,
				Hdp1,
				Hdp2,
				OddsType,
				Odds,
				MOdds,
				OddsSpread,
				Stake,
				Actual_Stake,
				WinLost,
				Comm,
				PlayerComm,
				Status,
				TransDate,
				WinLostDate,
				LiveIndicator,
				LiveHomeScore,
				LiveAwayScore,
				Ip,
				BetFrom,
				MatchId,
				BetCheck,
				TransDesc,
				BetdaqId,
				ExtraInfo,
				WalletType,
				RefCode,
				WhTicket)
			SELECT
				b.transid,
				b.refno,
				b.custid,
				b.currency,
				b.bettype,
				b.betid,
				b.betteam,
				b.hdp1,
				b.hdp2,
				b.oddstype,
				b.odds,
				b.modds,
				b.oddsspread,
				b.stake,
				b.actual_stake,
				b.winlost,
				b.comm,
				b.playercomm,
				b.status,
				b.transdate,
				b.winlostdate,
				b.liveindicator,
				b.livehomescore,
				b.liveawayscore,
				b.ip,
				b.betfrom,
				b.matchid,
				b.betcheck,
				b.transdesc,
				b.betdaqid,
				b.ExtraInfo,
				b.WalletType,
				ISNULL(b.RefCode, 0),
				3 AS WhTicket
			FROM bodb_Archive.dbo.bettrans_bk AS b WITH (NOLOCK, INDEX = IX_custid)
			WHERE b.custid = @CustId
				AND b.winlostdate BETWEEN @FromDate AND @TempToDate
				AND ',' + @StatusIdList + ',' LIKE '%,' + CONVERT(VARCHAR(3), b.statusID) + ',%'
				AND (@Platform = 0
					OR ',' + @BetFromList + ',' LIKE '%,' + b.betfrom + ',%')
				AND (@LiveIndicator = 3
					OR (b.bettype IN (9, 29) AND b.livehomescore = @LiveIndicator)
					OR (b.bettype NOT IN (9, 29) AND b.liveindicator = @LiveIndicator))
		END

		IF EXISTS (SELECT TOP(1) 1 FROM #Data)
		BEGIN
			UPDATE b
			SET BATransId = ba.TransID
			FROM #Data AS b
				INNER JOIN bodb_Licensee.dbo.LicenseeBATransaction_active AS ba WITH (NOLOCK) ON b.transid = ba.TransID
			WHERE b.WhTicket = 1

			UPDATE b
			SET BATransId = ba.TransID
			FROM #Data AS b
				INNER JOIN bodb_Licensee.dbo.LicenseeBATransaction_bk AS ba WITH (NOLOCK) ON b.transid = ba.TransID
			WHERE b.WhTicket IN (2, 3)

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
			SET ProductID = s.ProductID,
				EventType = s.EventType,
				SubProduct = s.SubProduct
			FROM #Data AS b
				INNER JOIN dbo.f_SportBettypeMatrix_Sel (0, 0, 0, 2, '', @ProductList, @IsTest) AS s ON b.bettype = s.bettype

			DELETE #Data
			WHERE ProductID IS NULL
				OR BetType IN (901, 902, 903, 904, 911, 912, 913, 914)
				OR BetType BETWEEN 801 AND 899
				OR (@ShowSB = 0
					AND ProductId = 1
					AND BetType NOT IN (901, 902, 903, 904, 911, 912, 913, 914)
					AND BATransId IS NULL)
				OR (@ShowBA = 0
					AND ProductId = 1
					AND BetType NOT IN (901, 902, 903, 904, 911, 912, 913, 914)
					AND BATransId IS NOT NULL)

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
					e.FirstExchangeDateByMonth,
					e.LastExchangeDateByMonth,
					CASE
						WHEN @BaseCurrency = 'MYR' THEN e.MYR
						WHEN @BaseCurrency = 'USD' THEN e.USD
						WHEN @BaseCurrency = 'EUR' THEN e.EUR
						WHEN @BaseCurrency = 'CNY' THEN e.CNY
						WHEN @BaseCurrency = 'IDR' THEN e.IDR
						WHEN @BaseCurrency = 'GBP' THEN e.GBP
						WHEN @BaseCurrency = 'THB' THEN e.THB
						ELSE 1
					END AS Rate
				FROM dbo.Lrf_f_GetSubExchangeDaily(@ExFromDate, @ExToDate) AS e
				WHERE e.ExchangeId = @Currency
					AND EXISTS (SELECT 1 FROM #Data WHERE WinLostDate BETWEEN e.FirstExchangeDateByMonth AND e.LastExchangeDateByMonth)
			END

			-- Return data
			SELECT
				@TotalRows		= COUNT(b.TransId),
				@SumStake		= SUM(b.Stake		* ISNULL(e.Rate, 1)),
				@SumWinlost		= SUM(b.WinLost		* ISNULL(e.Rate, 1)),
				@SumLicenseeWL	= SUM(b.LicenseeWL	* ISNULL(e.Rate, 1)),
				@SumComm		= SUM(b.Comm		* ISNULL(e.Rate, 1)),
				@SumPlayerComm	= SUM(b.PlayerComm	* ISNULL(e.Rate, 1))
			FROM #Data AS b
				LEFT JOIN #ExchangeRate AS e ON b.WinLostDate BETWEEN e.FirstExchangeDateByMonth AND e.LastExchangeDateByMonth

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
							LEFT JOIN #ExchangeRate AS e ON d.WinLostDate BETWEEN e.FirstExchangeDateByMonth AND e.LastExchangeDateByMonth'
							ELSE N' '
						END + N'
					) AS a
				WHERE a.RowNum BETWEEN @RowStart AND @RowEnd
				ORDER BY a.RowNum'

			INSERT INTO #PagingData
			EXEC sp_executesql @Sql, N'@RowStart INT, @RowEnd INT', @RowStart, @RowEnd;

			DROP TABLE #Data

			-- bettrans
			IF EXISTS (SELECT TOP(1) 1 FROM #PagingData WHERE WhTicket = 1)
			BEGIN
				-- Sportsbook (EventType = 1)
				UPDATE b
				SET
					SportType = m.sporttype,
					BetId = ISNULL(b.BetId, 0),
					OddsSpread = ISNULL(b.oddsspread, 0),
					LeagueId = m.leagueid,
					MatchCode = m.matchcode,
					Race = '',
					HomeId = m.homeid,
					AwayId = m.awayid,
					BetStatus = m.betstatus,
					IsNeutral = ISNULL(m.IsNeutral, CONVERT(BIT, 0)),
					ShowTime = '',
					BetCheck = CASE
									WHEN b.BetType IN (216, 217) THEN b.BetCheck
									ELSE ''
								END,
					TransDesc = ISNULL(b.transdesc, ''),
					BetdaqId = ISNULL(b.betdaqid, -1),
					ExtraInfo = ISNULL(b.ExtraInfo, ''),
					OriginalStake = CASE
										WHEN b.ExtraInfo LIKE '%p25%' THEN
											ISNULL(CAST(('<xml>' + b.ExtraInfo + '</xml>') AS XML).value('data(/xml/p25/@s)[1]','MONEY'), 0)
										ELSE 0
									END,
					OriginalBetType = CASE
										WHEN b.stake <> 0 THEN -1
										ELSE 0
									END,
					WalletType = ISNULL(b.WalletType, 0),
					RefCode = ISNULL(b.RefCode, 0)
				FROM #PagingData AS b
					INNER JOIN dbo.match AS m WITH (NOLOCK) ON b.matchid = m.matchid
				WHERE b.WhTicket = 1 AND b.EventType = 1

				-- Outright
				UPDATE b
				SET
					SportType = l.sporttype,
					BetId = ISNULL(b.BetId, 0),
					BetTeam = '',
					Hdp1 = 0,
					Hdp2 = 0,
					OddsType = 0,
					OddsSpread = 0,
					LiveIndicator = 0,
					LiveHomeScore = 0,
					LiveAwayScore = 0,
					LeagueId = o.leagueid,
					MatchId = 0,
					MatchCode = o.matchcode,
					Race = o.groupmatch,
					HomeId = o.teamid,
					AwayId  = 0,
					BetStatus = '',
					IsNeutral = 0,
					ShowTime = '',
					BetCheck = '',
					TransDesc = '',
					BetdaqId = -1,
					ExtraInfo = '',
					OriginalStake = 0,
					OriginalBetType = 0,
					WalletType = 0,
					RefCode = 0
				FROM #PagingData AS b
					INNER JOIN dbo.outright AS o WITH (NOLOCK) ON b.matchid = o.orid
					INNER JOIN dbo.League AS l WITH (NOLOCK) ON o.leagueid = l.leagueid
				WHERE b.WhTicket = 1 AND b.BetType = 10
			END

			-- bettrans14
			IF EXISTS (SELECT TOP(1) 1 FROM #PagingData WHERE WhTicket = 2)
			BEGIN
				-- Sportsbook (EventType = 1)
				UPDATE b
				SET
					SportType = m.sporttype,
					BetId = ISNULL(b.BetId, 0),
					OddsSpread = ISNULL(b.oddsspread, 0),
					LeagueId = m.leagueid,
					MatchCode = m.matchcode,
					Race = '',
					HomeId = m.homeid,
					AwayId = m.awayid,
					BetStatus = m.betstatus,
					IsNeutral = ISNULL(m.IsNeutral, CONVERT(BIT, 0)),
					ShowTime = '',
					BetCheck = CASE
									WHEN b.BetType IN (216, 217) THEN b.BetCheck
									ELSE ''
								END,
					TransDesc = ISNULL(b.transdesc, ''),
					BetdaqId = ISNULL(b.betdaqid, -1),
					ExtraInfo = ISNULL(b.ExtraInfo, ''),
					OriginalStake = CASE
										WHEN b.ExtraInfo LIKE '%p25%' THEN
											ISNULL(CAST(('<xml>' + b.ExtraInfo + '</xml>') AS XML).value('data(/xml/p25/@s)[1]','MONEY'), 0)
										ELSE 0
									END,
					OriginalBetType = CASE
										WHEN b.stake <> 0 THEN -1
										ELSE 0
									END,
					WalletType = ISNULL(b.WalletType, 0),
					RefCode = ISNULL(b.RefCode, 0)
				FROM #PagingData AS b
					INNER JOIN dbo.match14 AS m WITH (NOLOCK) ON b.matchid = m.matchid
				WHERE b.WhTicket = 2 AND b.EventType = 1

				-- Outright
				UPDATE b
				SET
					SportType = l.sporttype,
					BetId = ISNULL(b.BetId, 0),
					BetTeam = '',
					Hdp1 = 0,
					Hdp2 = 0,
					OddsType = 0,
					OddsSpread = 0,
					LiveIndicator = 0,
					LiveHomeScore = 0,
					LiveAwayScore = 0,
					LeagueId = o.leagueid,
					MatchId = 0,
					MatchCode = o.matchcode,
					Race = o.groupmatch,
					HomeId = o.teamid,
					AwayId  = 0,
					BetStatus = '',
					IsNeutral = 0,
					ShowTime = '',
					BetCheck = '',
					TransDesc = '',
					BetdaqId = -1,
					ExtraInfo = '',
					OriginalStake = 0,
					OriginalBetType = 0,
					WalletType = 0,
					RefCode = 0
				FROM #PagingData AS b
					INNER JOIN dbo.outright14 AS o WITH (NOLOCK) ON b.matchid = o.orid
					INNER JOIN dbo.League AS l WITH (NOLOCK) ON o.leagueid = l.leagueid
				WHERE b.WhTicket = 2 AND b.BetType = 10
			END

			-- bettrans_bk
			IF EXISTS (SELECT TOP(1) 1 FROM #PagingData WHERE WhTicket = 3)
			BEGIN
				-- Sportsbook (EventType = 1)
				UPDATE b
				SET
					SportType = m.sporttype,
					BetId = ISNULL(b.BetId, 0),
					OddsSpread = ISNULL(b.oddsspread, 0),
					LeagueId = m.leagueid,
					MatchCode = m.matchcode,
					Race = '',
					HomeId = m.homeid,
					AwayId = m.awayid,
					BetStatus = m.betstatus,
					IsNeutral = ISNULL(m.IsNeutral, CONVERT(BIT, 0)),
					ShowTime = '',
					BetCheck = CASE
									WHEN b.BetType IN (216, 217) THEN b.BetCheck
									ELSE ''
								END,
					TransDesc = ISNULL(b.transdesc, ''),
					BetdaqId = ISNULL(b.betdaqid, -1),
					ExtraInfo = ISNULL(b.ExtraInfo, ''),
					OriginalStake = CASE
										WHEN b.ExtraInfo LIKE '%p25%' THEN
											ISNULL(CAST(('<xml>' + b.ExtraInfo + '</xml>') AS XML).value('data(/xml/p25/@s)[1]','MONEY'), 0)
										ELSE 0
									END,
					OriginalBetType = CASE
										WHEN b.stake <> 0 THEN -1
										ELSE 0
									END,
					WalletType = ISNULL(b.WalletType, 0),
					RefCode = ISNULL(b.RefCode, 0)
				FROM #PagingData AS b
					INNER JOIN bodb_Archive.dbo.match_bk AS m WITH (NOLOCK) ON b.matchid = m.matchid
				WHERE b.WhTicket = 3 AND b.EventType = 1

				-- Outright
				UPDATE b
				SET
					SportType = l.sporttype,
					BetId = ISNULL(b.BetId, 0),
					BetTeam = '',
					Hdp1 = 0,
					Hdp2 = 0,
					OddsType = 0,
					OddsSpread = 0,
					LiveIndicator = 0,
					LiveHomeScore = 0,
					LiveAwayScore = 0,
					LeagueId = o.leagueid,
					MatchId = 0,
					MatchCode = o.matchcode,
					Race = o.groupmatch,
					HomeId = o.teamid,
					AwayId  = 0,
					BetStatus = '',
					IsNeutral = 0,
					ShowTime = '',
					BetCheck = '',
					TransDesc = '',
					BetdaqId = -1,
					ExtraInfo = '',
					OriginalStake = 0,
					OriginalBetType = 0,
					WalletType = 0,
					RefCode = 0
				FROM #PagingData AS b
					INNER JOIN bodb_Archive.dbo.outright_bk AS o WITH (NOLOCK) ON b.matchid = o.orid
					INNER JOIN dbo.League AS l WITH (NOLOCK) ON o.leagueid = l.leagueid
				WHERE b.WhTicket = 3 AND b.BetType = 10
			END

			-- System Parlay
			UPDATE b
			SET
				TransId = CASE
							WHEN b.bettype = 29 AND ISNULL(b.betid, 0) > 0 THEN b.betid
							ELSE b.transid
						END,
				SportType = 0,
				BetId = ISNULL(b.BetId, 0),
				OddsType = 0,
				OddsSpread = 0,
				LiveIndicator = 0,
				LiveAwayScore = 0,
				LeagueId = 0,
				MatchId = 0,
				MatchCode = '',
				Race = '',
				HomeId = 0,
				AwayId  = 0,
				BetStatus = '',
				IsNeutral = 0,
				ShowTime = '',
				BetCheck = ISNULL(b.betcheck, ''),
				TransDesc = '',
				BetdaqId = -1,
				ExtraInfo = '',
				OriginalStake = 0,
				OriginalBetType = 0,
				WalletType = 0,
				RefCode = 0
			FROM #PagingData AS b
			WHERE b.BetType IN (9, 29)
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
		a.LiveIndicator,
		a.LiveHomeScore,
		a.LiveAwayScore,
		a.Race,
		a.LeagueId,
		a.MatchId,
		a.MatchCode,
		a.HomeId,
		a.AwayId,
		a.IsNeutral,
		a.BetStatus,
		a.ShowTime,
		a.Currency,
		a.Stake * ISNULL(e.Rate, 1) AS Stake,
		a.Actual_Stake * ISNULL(e.Rate, 1) AS Actual_Stake,
		a.WinLost * ISNULL(e.Rate, 1) AS WinLost,
		a.LicenseeWL * ISNULL(e.Rate, 1) AS LicenseeWL,
		a.Comm * ISNULL(e.Rate, 1) AS Comm,
		a.PlayerComm * ISNULL(e.Rate, 1) AS PlayerComm,
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
		LEFT JOIN #ExchangeRate AS e ON a.WinLostDate BETWEEN e.FirstExchangeDateByMonth AND e.LastExchangeDateByMonth
	ORDER BY a.RowNum

	SELECT DISTINCT * FROM @Detail

	DROP TABLE #PagingData
	DROP TABLE #ExchangeRate
END







GO
GRANT EXECUTE ON [dbo].[Lrf_BetList_Mem] TO [bodbLicenseeNet]
GO
GRANT VIEW DEFINITION ON [dbo].[Lrf_BetList_Mem] TO vnteam
GO
