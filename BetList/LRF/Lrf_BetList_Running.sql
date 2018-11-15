/*<info serverAlias="DB042-bodb02" executers="bodbLicenseeNet" viewers="vnteam" isFunction="0" isNested="0"></info>*/

ALTER PROCEDURE [dbo].[Lrf_BetList_Running]
	@AgentList		VARCHAR(MAX),
	@CustId			INT				= 0,
	@Username		VARCHAR(50)		= '',
	@FromDate		DATETIME,
	@ToDate			DATETIME,
	@CurrencyId		TINYINT			= 0,
	@BaseCurrency	VARCHAR(10)		= '',
	@PageSize		INT				= 1000,
	@PageIndex		INT				= 1,
	@Sort			NVARCHAR(50)	= N'TransId ASC',
	@ProductList	VARCHAR(200)	= '',
	@ShowBA			BIT				= 0,	-- BA
	@TotalRows		INT				= 0 OUTPUT,
	@SumStake		MONEY			= 0 OUTPUT
AS

/*
	Created: Kos@20180613
	Task: Betting Ticket Center - Running Bet List
	DB: DB042.bodb02
	Revisions:
		- 20180613@Kos: Created [#Redmine: 80941]
		- 20181114@Kos: Change getting ticket status [#Redmine: 104664]
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
		IF @CurrencyId <> 0
		BEGIN
			DELETE @TempAg
			WHERE Currency <> @CurrencyId
		END

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

		IF @CustId = -1
			OR (@CustId <> 0
				AND NOT EXISTS (	SELECT 1 FROM dbo.custInfo AS c WITH (NOLOCK)
									WHERE c.custid = @CustId
										AND EXISTS (	SELECT 1 FROM @TempAg
														WHERE CustId = c.recommend AND Currency = c.currency)))
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
		SubProduct		VARCHAR(500)
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
		SubProduct		VARCHAR(500)
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
		IF @CustId = 0		-- Licensee level
		BEGIN
			INSERT INTO #Data (
				TransId,
				RefNo,
				BATransId,
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
				RefCode)
			SELECT
				b.transid,
				b.refno,
				ba.TransID,
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
				CASE
					WHEN b.status = 'running' AND ISNULL(b.SecAcceptFlag, 0) = 1 AND ISNULL(b.checktime, CURRENT_TIMESTAMP) > CURRENT_TIMESTAMP THEN 'waiting'
					ELSE b.status
				END AS status,
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
				ISNULL(b.RefCode, 0)
			FROM dbo.bettrans AS b WITH (NOLOCK)
				LEFT JOIN bodb_Licensee.dbo.LicenseeBATransaction_active AS ba WITH (NOLOCK) ON b.transid = ba.TransID
			WHERE EXISTS (SELECT 1 FROM @TempAg WHERE CustId = b.recommend)
				AND b.transdate BETWEEN @FromDate AND @ToDate
				AND b.statusID IN (0, 1)
		END
		ELSE		-- Customer level
		BEGIN
			INSERT INTO #Data (
				TransId,
				RefNo,
				BATransId,
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
				RefCode)
			SELECT
				b.transid,
				b.refno,
				ba.TransID,
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
				CASE
					WHEN b.status = 'running' AND ISNULL(b.SecAcceptFlag, 0) = 1 AND ISNULL(b.checktime, CURRENT_TIMESTAMP) > CURRENT_TIMESTAMP THEN 'waiting'
					ELSE b.status
				END AS status,
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
				ISNULL(b.RefCode, 0)
			FROM dbo.bettrans AS b WITH (NOLOCK)
				LEFT JOIN bodb_Licensee.dbo.LicenseeBATransaction_active AS ba WITH (NOLOCK) ON b.transid = ba.TransID
			WHERE b.custid = @CustId
				AND b.transdate BETWEEN @FromDate AND @ToDate
				AND b.statusID IN (0, 1)
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
			SET ProductID = s.ProductID,
				EventType = s.EventType,
				SubProduct = s.SubProduct
			FROM #Data AS b
				INNER JOIN dbo.f_SportBettypeMatrix_Sel (0, 0, 0, 2, '', @ProductList, @IsTest) AS s ON b.bettype = s.bettype

			DELETE #Data
			WHERE ProductID IS NULL
				OR BetType IN (901, 902, 903, 904, 911, 912, 913, 914)
				OR BetType BETWEEN 801 AND 899
				OR Currency NOT IN (SELECT DISTINCT Currency FROM @TempAg)
				OR (@ShowSB = 0 AND ProductId = 1 AND BATransId IS NULL)
				OR (@ShowBA = 0 AND ProductId = 1 AND BATransId IS NOT NULL)

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

			IF @BaseCurrency <> ''
			BEGIN
				INSERT INTO #ExchangeRate
				SELECT
					e.ExchangeId,
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
				FROM Lrf_f_GetExchangeDaily(DATEADD(DAY, DATEDIFF(DAY, 0, GETDATE()), 0), DATEADD(DAY, DATEDIFF(DAY, 0, GETDATE()), 0)) AS e
				WHERE EXISTS (SELECT 1 FROM #Data WHERE Currency = e.ExchangeId)
			END

			-- Get sort text
			IF @BaseCurrency <> '' AND @Sort LIKE '%Stake%'
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

			DROP TABLE #Data

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
			WHERE b.EventType = 1

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
			WHERE b.BetType = 10

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
			WHERE b.BetType = 29
		END
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
	ORDER BY a.RowNum

	SELECT DISTINCT * FROM @Detail

	DROP TABLE #PagingData
	DROP TABLE #ExchangeRate
END







GO
GRANT EXECUTE ON [dbo].[Lrf_BetList_Running] TO [bodbLicenseeNet]
GO
GRANT VIEW DEFINITION ON [dbo].[Lrf_BetList_Running] TO vnteam
GO
