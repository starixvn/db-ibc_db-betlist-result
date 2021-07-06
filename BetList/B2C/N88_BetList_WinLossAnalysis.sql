/*<info serverAlias="DBACC-bodb02" executers="bodbLicenseeNet" isFunction="0" isNested=""></info>*/

ALTER PROCEDURE [dbo].[N88_BetList_WinLossAnalysis]
	@CustId				INT,
	@FilterBy			TINYINT,
	@FromDate			DATETIME,
	@ToDate				DATETIME,
	@MoveBetsDay		SMALLDATETIME,
	@BalanceUpDay		SMALLDATETIME,
	@TimeZone			SMALLINT	= -4,
	@ProductId			INT,
	@BaseCurrency		VARCHAR(3),
	@ExcludeDrawTicket	BIT,
	@PageIndex			INT			= 1,
	@PageSize			INT			= 50,
	@TotalRows			INT			= 0 OUTPUT,
	@SumWinLost			MONEY		= 0 OUTPUT,
	@SumLicenseeWL		MONEY		= 0 OUTPUT,
	@SumComm			MONEY		= 0 OUTPUT,
	@SumPlayerComm		MONEY		= 0 OUTPUT
AS

/*
	Created: 20210504@Kos
	DB: DBACC-bodb02
	Task: B2C - Bet list of Win Loss Analysis Report [Redmine: #139333]

	Revisions:
		- 20210504@Kos: Created [Redmine: #139333]
		- 20210706@Kos: Support Beach Volleyball [Redmine: #157296]

*/

BEGIN
	SET NOCOUNT ON

	DECLARE @FDate DATETIME,
		@TDate DATETIME

	SELECT @FDate = DATEADD(DAY, -1, @FromDate),
		@TDate = DATEADD(DAY, 1, @ToDate)

	-- Data on GMT + 0 --> convert timezone
	DECLARE @FromDateTimeGMT0	DATETIME,
		@ToDateTimeGMT0			DATETIME

	SELECT @FromDateTimeGMT0	= DATEADD(HOUR, -@TimeZone, CONVERT(DATETIME, @FromDate)),
		@ToDateTimeGMT0			= DATEADD(HOUR, -@TimeZone, CONVERT(DATETIME, @ToDate))

	DECLARE @CustIdTmp VARCHAR(45)

	SET @CustIdTmp = CAST(@CustId AS VARCHAR(45))

	-- 1. Get raw data
	CREATE TABLE #Tickets (TransId BIGINT)

	IF @FilterBy = 1	-- By winlostdate
	BEGIN
		INSERT INTO #Tickets (TransId)
		SELECT CASE
					WHEN ISNUMERIC(r.TransId) = 1 THEN CAST(r.TransId AS BIGINT)
					ELSE 0
				END AS TransId
		FROM DBN88.bodb_N88.dbo.TpBetRecord r WITH (NOLOCK)
		WHERE r.SettledTime >= @FromDateTimeGMT0
			AND r.SettledTime < DATEADD(DAY, 1, @ToDateTimeGMT0)
			AND r.CustId = @CustIdTmp
			AND r.GameType = @ProductId
			AND 1 = CASE
						WHEN @ExcludeDrawTicket = 1 AND r.TicketStatus IN (1, 2, 6) THEN 1
						WHEN @ExcludeDrawTicket = 0 AND r.TicketStatus IN (1, 2, 4, 6) THEN 1
						ELSE 0
					END
	END
	ELSE		-- By transdate
	BEGIN
		INSERT INTO #Tickets (TransId)
		SELECT CASE
					WHEN ISNUMERIC(r.TransId) = 1 THEN CAST(r.TransId AS BIGINT)
					ELSE 0
				END AS TransId
		FROM DBN88.bodb_N88.dbo.TpBetRecord r WITH (NOLOCK)
		WHERE r.TransTime >= @FromDateTimeGMT0 AND r.TransTime < DATEADD(DAY, 1, @ToDateTimeGMT0)
			AND r.CustId = @CustIdTmp
			AND r.GameType = @ProductId
			AND 1 = CASE
						WHEN @ExcludeDrawTicket = 1 AND r.TicketStatus IN (1, 2, 6) THEN 1
						WHEN @ExcludeDrawTicket = 0 AND r.TicketStatus IN (1, 2, 4, 6) THEN 1
						ELSE 0
					END
	END

	-- Get Sport Bettype Matrix
	DECLARE @SportBettype TABLE(ProductID TINYINT, BetType SMALLINT, EventType TINYINT)

	DECLARE @IsTest BIT = 0

	SELECT @IsTest = dbo.f_CheckSPVersion(@@PROCID)

	INSERT INTO @SportBettype
	SELECT ProductID, BetType, EventType
	FROM dbo.f_SportBettypeMatrix_Sel (1, 0, 0, 2, '', '', @IsTest)

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
		Ip					NVARCHAR(15),
		LeagueId			INT,
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
		Ip					NVARCHAR(15),
		LeagueId			INT,
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

	CREATE TABLE #ExchangeRate (
		FirstExchangeDateByMonth	SMALLDATETIME,
		LastExchangeDateByMonth		SMALLDATETIME,
		Rate						FLOAT
	)

	DECLARE @TempToDate	SMALLDATETIME,
		@TempFromDate	SMALLDATETIME

	-- bettrans
	IF EXISTS (SELECT 1 FROM #Tickets)
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
		FROM dbo.bettrans AS b WITH (NOLOCK)
			INNER JOIN #Tickets AS t ON b.transid = t.transid
		WHERE b.winlostdate > @MoveBetsDay

		DELETE FROM #Tickets
		WHERE TransId IN (SELECT TransId FROM #Data)
	END

	-- bettrans14
	IF EXISTS (SELECT 1 FROM #Tickets)
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
		FROM dbo.bettrans14 AS b WITH (NOLOCK)
			INNER JOIN #Tickets AS t ON b.transid = t.transid
		WHERE b.winlostdate BETWEEN @BalanceUpDay AND @MoveBetsDay

		DELETE FROM #Tickets
		WHERE TransId IN (SELECT TransId FROM #Data)
	END

	-- bettrans_bk
	IF EXISTS (SELECT 1 FROM #Tickets)
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
			3 AS TableID
		FROM bodb_Archive.dbo.bettrans_bk AS b WITH (NOLOCK, INDEX = IX_transid)
			INNER JOIN #Tickets AS t ON b.transid = t.transid
		WHERE b.winlostdate < @BalanceUpDay
	END

	IF EXISTS (SELECT TOP(1) 1 FROM #Data)
	BEGIN
		-- Get Sport/Bettype info
		UPDATE b
		SET
			BATransId = CASE
							WHEN b.TableID = 1 THEN ba.TransID
							WHEN b.TableID IN (2, 3) THEN babk.TransID
						END,
			Product = CASE
						WHEN s.EventType = 0 AND s.ProductID = 1 THEN 'Parlay'		-- Sportsbook Parlay
						WHEN s.EventType = 1 AND s.ProductID = 1 THEN 'SB'			-- Sportsbook
						WHEN s.EventType = 2 AND s.ProductID = 1 THEN 'Outright'
						ELSE 'Unknown'
					END
		FROM #Data AS b
			INNER JOIN @SportBettype AS s ON b.bettype = s.bettype
			LEFT JOIN bodb_Licensee.dbo.LicenseeBATransaction_active AS ba WITH (NOLOCK) ON b.transid = ba.TransID AND b.TableID = 1
			LEFT JOIN bodb_Licensee.dbo.LicenseeBATransaction_bk AS babk WITH (NOLOCK) ON b.transid = babk.TransID AND b.TableID IN (2, 3)

		DELETE #Data
		WHERE Product = 'Unknown'
			OR Product IS NULL
			OR BetType IN (901, 902, 903, 904, 914)
			OR BetType BETWEEN 801 AND 899

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
					WHEN @BaseCurrency = 'INH' THEN e.INH
					WHEN @BaseCurrency = 'BDT' THEN e.BDT
					WHEN @BaseCurrency = 'INR' THEN e.INR
					ELSE 1
				END AS Rate
			FROM dbo.Lrf_f_GetSubExchangeDaily(@ExFromDate, @ExToDate) AS e
			WHERE EXISTS (SELECT 1 FROM #Data
						WHERE Currency = e.ExchangeId
							AND WinLostDate BETWEEN e.FirstExchangeDateByMonth AND e.LastExchangeDateByMonth)
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
								WHEN b.Product IN ('SB') THEN m.sporttype
								WHEN b.Product IN ('Outright') THEN l.sporttype
								ELSE 0
							END,
				BetTeam = CASE
								WHEN b.Product IN ('SB', 'Parlay') THEN b.BetTeam
								ELSE ''
							END,
				Hdp1 = CASE
							WHEN b.Product IN ('SB', 'Parlay') THEN b.Hdp1
							ELSE 0
						END,
				Hdp2 = CASE
							WHEN b.Product IN ('SB', 'Parlay') THEN b.Hdp2
							ELSE 0
						END,
				OddsType = CASE
							WHEN b.Product IN ('SB', 'Outright') THEN b.OddsType
							ELSE 0
						END,
				Odds = CASE
							WHEN b.Product IN ('SB', 'Outright', 'Parlay') THEN b.Odds
							ELSE 0
						END,
				MOdds = CASE 
							WHEN b.Product IN ('SB', 'Outright', 'Parlay')  THEN b.modds 
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
									WHEN b.Product IN ('SB', 'Outright', 'Parlay') THEN b.livehomescore
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
				MatchId = CASE
								WHEN b.Product IN ('SB') THEN m.matchid
								ELSE 0
							END,
				MatchCode = CASE
								WHEN b.Product IN ('SB') THEN m.matchcode
								ELSE ''
							END,
				EventDate = CASE
							WHEN b.Product IN ('SB', 'CO') THEN m.GlobalShowTime
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
								WHEN b.Product IN ('SB', 'Parlay') THEN ISNULL(b.betcheck, '')
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
								WHEN b.Product IN ('SB', 'Parlay', 'Outright') THEN ISNULL(b.ExtraInfo, '')
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
				LEFT JOIN dbo.outright AS o WITH (NOLOCK) ON b.Product IN ('Outright') AND b.matchid = o.orid
				LEFT JOIN dbo.League AS l WITH (NOLOCK) ON b.Product IN ('Outright') AND o.leagueID = l.leagueID
			WHERE b.TableID = 1
		END

		-- bettrans14
		IF EXISTS (SELECT TOP(1) 1 FROM #PagingData WHERE TableID = 2)
		BEGIN
			UPDATE b
			SET
				TransId = CASE
							WHEN b.Product = 'Parlay' AND b.BetType = 29 AND ISNULL(b.BetId, 0) > 0 THEN b.BetId
							ELSE b.TransId
						END,
				SportType = CASE
								WHEN b.Product IN ('SB') THEN m.sporttype
								WHEN b.Product IN ('Outright') THEN l.sporttype
								ELSE 0
							END,
				BetTeam = CASE
								WHEN b.Product IN ('SB', 'Parlay') THEN b.BetTeam
								ELSE ''
							END,
				Hdp1 = CASE
							WHEN b.Product IN ('SB', 'Parlay') THEN b.Hdp1
							ELSE 0
						END,
				Hdp2 = CASE
							WHEN b.Product IN ('SB', 'Parlay') THEN b.Hdp2
							ELSE 0
						END,
				OddsType = CASE
							WHEN b.Product IN ('SB', 'Outright') THEN b.OddsType
							ELSE 0
						END,
				Odds = CASE
							WHEN b.Product IN ('SB', 'Outright', 'Parlay') THEN b.Odds
							ELSE 0
						END,
				MOdds = CASE 
							WHEN b.Product IN ('SB', 'Outright', 'Parlay')  THEN b.modds 
							ELSE 0
						END,
				SettlementStatus = 0,
				LiveIndicator = CASE
									WHEN b.Product IN ('SB') THEN b.liveindicator
									ELSE 0
								END,
				LiveHomeScore = CASE
									WHEN b.Product IN ('SB', 'Outright', 'Parlay') THEN b.livehomescore
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
				MatchId = CASE
								WHEN b.Product IN ('SB') THEN m.matchid
								ELSE 0
							END,
				MatchCode = CASE
								WHEN b.Product IN ('SB') THEN m.matchcode
								ELSE ''
							END,
				EventDate = CASE
							WHEN b.Product IN ('SB', 'CO') THEN m.GlobalShowTime
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
								WHEN b.Product IN ('SB', 'Parlay') THEN ISNULL(b.betcheck, '')
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
								WHEN b.Product IN ('SB', 'Parlay', 'Outright') THEN ISNULL(b.ExtraInfo, '')
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
				LEFT JOIN dbo.outright14 AS o WITH (NOLOCK) ON b.Product IN ('Outright') AND b.matchid = o.orid
				LEFT JOIN dbo.League AS l WITH (NOLOCK) ON b.Product IN ('Outright') AND o.leagueID = l.leagueID
			WHERE b.TableID = 2
		END

		-- bettrans_bk
		IF EXISTS (SELECT TOP(1) 1 FROM #PagingData WHERE TableID = 3)
		BEGIN
			UPDATE b
			SET
				TransId = CASE
							WHEN b.Product = 'Parlay' AND b.BetType = 29 AND ISNULL(b.BetId, 0) > 0 THEN b.BetId
							ELSE b.TransId
						END,
				SportType = CASE
								WHEN b.Product IN ('SB') THEN m.sporttype
								WHEN b.Product IN ('Outright') THEN l.sporttype
								ELSE 0
							END,
				BetTeam = CASE
								WHEN b.Product IN ('SB', 'Parlay') THEN b.BetTeam
								ELSE ''
							END,
				Hdp1 = CASE
							WHEN b.Product IN ('SB', 'Parlay') THEN b.Hdp1
							ELSE 0
						END,
				Hdp2 = CASE
							WHEN b.Product IN ('SB', 'Parlay') THEN b.Hdp2
							ELSE 0
						END,
				OddsType = CASE
							WHEN b.Product IN ('SB', 'Outright') THEN b.OddsType
							ELSE 0
						END,
				Odds = CASE
							WHEN b.Product IN ('SB', 'Outright', 'Parlay') THEN b.Odds
							ELSE 0
						END,
				MOdds = CASE 
							WHEN b.Product IN ('SB', 'Outright', 'Parlay')  THEN b.modds 
							ELSE 0
						END,
				SettlementStatus = 0,
				LiveIndicator = CASE
									WHEN b.Product IN ('SB') THEN b.liveindicator
									ELSE 0
								END,
				LiveHomeScore = CASE
									WHEN b.Product IN ('SB', 'Outright', 'Parlay') THEN b.livehomescore
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
				MatchId = CASE
								WHEN b.Product IN ('SB') THEN m.matchid
								ELSE 0
							END,
				MatchCode = CASE
								WHEN b.Product IN ('SB') THEN m.matchcode
								ELSE ''
							END,
				EventDate = CASE
							WHEN b.Product IN ('SB', 'CO') THEN m.GlobalShowTime
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
								WHEN b.Product IN ('SB', 'Parlay') THEN ISNULL(b.betcheck, '')
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
								WHEN b.Product IN ('SB', 'Parlay', 'Outright') THEN ISNULL(b.ExtraInfo, '')
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
				LEFT JOIN bodb_Archive.dbo.match_bk AS m WITH (NOLOCK) ON b.Product IN ('SB') AND b.matchid = m.matchid
				LEFT JOIN bodb_Archive.dbo.outright_bk AS o WITH (NOLOCK) ON b.Product IN ('Outright') AND b.matchid = o.orid
				LEFT JOIN dbo.League AS l WITH (NOLOCK) ON b.Product IN ('Outright') AND o.leagueID = l.leagueID
			WHERE b.TableID = 3
		END
	END

	-- Return data
	SELECT
		c.username,
		SUBSTRING(c.username2,  CHARINDEX('$', c.username2) + 1, LEN(c.username2) - CHARINDEX('$', c.username2)) AS Nickname,
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
		a.MatchId,
		a.MatchCode,
		a.EventDate,
		a.HomeId,
		a.AwayId,
		a.IsNeutral,
		a.BetStatus,
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
		a.RefCode
	FROM
		#PagingData AS a
		INNER JOIN dbo.Customer AS c WITH (NOLOCK) ON a.CustId = c.custid
		LEFT JOIN #ExchangeRate AS e ON a.WinLostDate BETWEEN e.FirstExchangeDateByMonth AND e.LastExchangeDateByMonth
	ORDER BY a.RowNum ASC

	DROP TABLE #Data
	DROP TABLE #PagingData
	DROP TABLE #ExchangeRate
	DROP TABLE #Tickets
END
GO