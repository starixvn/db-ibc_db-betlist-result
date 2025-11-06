/*<info serverAlias="DBACC-bodb02" executers="wsv_lap" isFunction="0" isNested=""></info>*/

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
		- 20210929@Kos: Extend length to support IPv6 [Redmine: 162342]
		- 20211029@Kos: Decompress IP in bk range [Redmine: 162342]
		- 20220301@Kos: Support archive process [Redmine: 167823]
		- 20250212@Kos: Remove BA [RedmineID: #216882]
		- 20251028@Kelvin: Integrate - Jacktime - Basketball Main Bettype Hybrid Parlay [#Redmine: 242357]
*/

BEGIN
	SET NOCOUNT ON

	-- Data on GMT + 0 --> convert timezone
	DECLARE @FromDateTimeGMT0	DATETIME,
		@ToDateTimeGMT0			DATETIME

	SELECT @FromDateTimeGMT0	= DATEADD(HOUR, -@TimeZone, CONVERT(DATETIME, @FromDate)),
		@ToDateTimeGMT0			= DATEADD(HOUR, -@TimeZone, CONVERT(DATETIME, DATEADD(DAY, 1, @ToDate)))

	DECLARE @FDate	DATETIME = @FromDateTimeGMT0,
		@TDate		DATETIME = @ToDateTimeGMT0

	DECLARE @ArchiveDate DATETIME

	SELECT  @ArchiveDate = SValue
	FROM DBN88.bodb_N88.dbo.SystemSettings WITH (NOLOCK)
	WHERE SName = 'ArchiveData_Date'

	DECLARE @CustIdTmp VARCHAR(45)

	SET @CustIdTmp = CAST(@CustId AS VARCHAR(45))

	-- 1. Get raw data
	CREATE TABLE #Tickets (TransId BIGINT)

	-- TpBetRecord
	IF @ToDateTimeGMT0 >= @ArchiveDate
	BEGIN
		SELECT @FDate = CASE
							WHEN @FromDateTimeGMT0 > @ArchiveDate THEN @FromDateTimeGMT0
							ELSE @ArchiveDate
						END,
			@TDate = @ToDateTimeGMT0

		IF @FilterBy = 1	-- By winlostdate
		BEGIN
			INSERT INTO #Tickets (TransId)
			SELECT CASE
						WHEN ISNUMERIC(r.TransId) = 1 THEN CAST(r.TransId AS BIGINT)
						ELSE 0
					END AS TransId
			FROM DBN88.bodb_N88.dbo.TpBetRecord AS r WITH (NOLOCK)
			WHERE r.SettledTime >= @FDate AND r.SettledTime < @TDate
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
			FROM DBN88.bodb_N88.dbo.TpBetRecord AS r WITH (NOLOCK)
			WHERE r.TransTime >= @FDate AND r.TransTime < @TDate
				AND r.CustId = @CustIdTmp
				AND r.GameType = @ProductId
				AND 1 = CASE
							WHEN @ExcludeDrawTicket = 1 AND r.TicketStatus IN (1, 2, 6) THEN 1
							WHEN @ExcludeDrawTicket = 0 AND r.TicketStatus IN (1, 2, 4, 6) THEN 1
							ELSE 0
						END
		END
	END

	-- TpBetRecord_bk
	IF @FromDateTimeGMT0 < @ArchiveDate
	BEGIN
		SELECT @FDate = @FromDateTimeGMT0,
			@TDate = CASE
						WHEN @ToDateTimeGMT0 < @ArchiveDate THEN @ToDateTimeGMT0
						ELSE @ArchiveDate
					END

		IF @FilterBy = 1	-- By winlostdate
		BEGIN
			INSERT INTO #Tickets (TransId)
			SELECT CASE
						WHEN ISNUMERIC(rbk.TransId) = 1 THEN CAST(rbk.TransId AS BIGINT)
						ELSE 0
					END AS TransId
			FROM DBN88.bodb_N88_Archive.dbo.TpBetRecord_bk AS rbk WITH (NOLOCK)
			WHERE rbk.SettledTime >= @FDate AND rbk.SettledTime < @TDate
				AND rbk.CustId = @CustIdTmp
				AND rbk.GameType = @ProductId
				AND 1 = CASE
							WHEN @ExcludeDrawTicket = 1 AND rbk.TicketStatus IN (1, 2, 6) THEN 1
							WHEN @ExcludeDrawTicket = 0 AND rbk.TicketStatus IN (1, 2, 4, 6) THEN 1
							ELSE 0
						END
		END
		ELSE		-- By transdate
		BEGIN
			INSERT INTO #Tickets (TransId)
			SELECT CASE
						WHEN ISNUMERIC(rbk.TransId) = 1 THEN CAST(rbk.TransId AS BIGINT)
						ELSE 0
					END AS TransId
			FROM DBN88.bodb_N88_Archive.dbo.TpBetRecord_bk AS rbk WITH (NOLOCK)
			WHERE rbk.TransTime >= @FDate AND rbk.TransTime < @TDate
				AND rbk.CustId = @CustIdTmp
				AND rbk.GameType = @ProductId
				AND 1 = CASE
							WHEN @ExcludeDrawTicket = 1 AND rbk.TicketStatus IN (1, 2, 6) THEN 1
							WHEN @ExcludeDrawTicket = 0 AND rbk.TicketStatus IN (1, 2, 4, 6) THEN 1
							ELSE 0
						END
		END
	END

	-- Get Sport Bettype Matrix
	DECLARE @SportBettype TABLE(ProductID TINYINT, BetType SMALLINT, EventType TINYINT)

	DECLARE @IsTest BIT = 0

	SELECT @IsTest = dbo.f_CheckSPVersion(@@PROCID)

	INSERT INTO @SportBettype (ProductID, BetType, EventType)
	SELECT ProductID, BetType, EventType
	FROM dbo.f_SportBettypeMatrix_Sel (1, 0, 0, 2, '', '', @IsTest)

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
			TransId, RefNo, CustId, Currency, Recommend, BetType, BetId, BetTeam, Hdp1, Hdp2,
			OddsId, OddsType, Odds, MOdds, OddsSpread, Stake, Actual_Stake, AWinLost, WinLost, PlayerComm,
			Comm, Status, TransDate, WinLostDate, LiveIndicator, LiveHomeScore, LiveAwayScore, Ip, MatchId, BetCheck,
			ComStatus, TransDesc, BetdaqId, ExtraInfo, WalletType, RefCode, TableID
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
			TransId, RefNo, CustId, Currency, Recommend, BetType, BetId, BetTeam, Hdp1, Hdp2,
			OddsId, OddsType, Odds, MOdds, OddsSpread, Stake, Actual_Stake, AWinLost, WinLost, PlayerComm,
			Comm, Status, TransDate, WinLostDate, LiveIndicator, LiveHomeScore, LiveAwayScore, Ip, MatchId,
			BetCheck, ComStatus, TransDesc, BetdaqId, ExtraInfo, WalletType, RefCode, TableID
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
			b14.ExtraInfo,
			b14.WalletType,
			ISNULL(b14.RefCode, 0),
			2 AS TableID
		FROM dbo.bettrans14 AS b14 WITH (NOLOCK)
			INNER JOIN #Tickets AS t ON b14.transid = t.transid
		WHERE b14.winlostdate BETWEEN @BalanceUpDay AND @MoveBetsDay

		DELETE FROM #Tickets
		WHERE TransId IN (SELECT TransId FROM #Data)
	END

	-- bettrans_bk
	IF EXISTS (SELECT 1 FROM #Tickets)
	BEGIN
		INSERT INTO #Data (
			TransId, RefNo, CustId, Currency, Recommend, BetType, BetId, BetTeam, Hdp1, Hdp2,
			OddsId, OddsType, Odds, MOdds, OddsSpread, Stake, Actual_Stake, AWinLost, WinLost, PlayerComm,
			Comm, Status, TransDate, WinLostDate, LiveIndicator, LiveHomeScore, LiveAwayScore, Ip, MatchId,
			BetCheck, ComStatus, TransDesc, BetdaqId, ExtraInfo, WalletType, RefCode, TableID
		)
		SELECT
			bk.transid,
			bk.refno,
			bk.custid,
			bk.currency,
			bk.recommend,
			bk.bettype,
			ISNULL(bk.BetId, 0) AS BetId,
			bk.betteam,
			bk.hdp1,
			bk.hdp2,
			bk.oddsid,
			bk.oddstype,
			bk.odds,
			bk.modds,
			bk.oddsspread,
			bk.stake,
			bk.actual_stake,
			bk.awinlost,
			bk.winlost,
			bk.playercomm,
			bk.comm,
			bk.status,
			bk.transdate,
			bk.winlostdate,
			bk.liveindicator,
			bk.livehomescore,
			bk.liveawayscore,
			dp.IP,
			bk.matchid,
			bk.betcheck,
			bk.comstatus,
			bk.transdesc,
			bk.betdaqid,
			bk.ExtraInfo,
			bk.WalletType,
			ISNULL(bk.RefCode, 0),
			3 AS TableID
		FROM bodb_Archive.dbo.bettrans_bk AS bk WITH (NOLOCK, INDEX = IX_transid)
			INNER JOIN #Tickets AS t ON bk.transid = t.transid
			CROSS APPLY dbo.f_IP_Decompress(bk.ip) AS dp
		WHERE bk.winlostdate < @BalanceUpDay
	END

	IF EXISTS (SELECT TOP(1) 1 FROM #Data)
	BEGIN
		-- Get Sport/Bettype info
		UPDATE b
		SET
			Product = CASE
						WHEN s.EventType = 0 AND s.ProductID = 1 THEN 'Parlay'		-- Sportsbook Parlay
						WHEN s.EventType = 1 AND s.ProductID = 1 THEN 'SB'			-- Sportsbook
						WHEN s.EventType = 2 AND s.ProductID = 1 THEN 'Outright'
						ELSE 'Unknown'
					END
		FROM #Data AS b
			INNER JOIN @SportBettype AS s ON b.bettype = s.bettype

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
			(
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

		DECLARE @ExFromDate SMALLDATETIME,
			@ExToDate SMALLDATETIME

		SELECT
			@ExFromDate = MIN(WinLostDate),
			@ExToDate = MAX(WinLostDate)
		FROM #Data

		-- Get exchange rate
		IF @BaseCurrency <> ''
		BEGIN
			INSERT INTO #ExchangeRate (FirstExchangeDateByMonth, LastExchangeDateByMonth, Rate)
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
						d.*
					FROM #Data d
				) AS a
			WHERE a.RowNum BETWEEN @RowStart AND @RowEnd
			ORDER BY a.RowNum ASC'

		INSERT INTO #PagingData
		(
			RowNum, TransId, RefNo, CustId, Currency, Recommend, SportType, BetType, BetId, BetTeam,
			Hdp1, Hdp2, OddsId, OddsType, Odds, MOdds, OddsSpread, Stake, Actual_Stake, AWinLost,
			WinLost, LicenseeWL, PlayerComm, Comm, Status, SettlementStatus, TransDate, WinLostDate, LiveIndicator, LiveHomeScore,
			LiveAwayScore, Ip, LeagueId, MatchId, MatchCode, EventDate, HomeId, AwayId, BetStatus, IsNeutral,
			BetCheck, ComStatus, TransDesc, BetdaqId, ExtraInfo, OriginalStake, OriginalBetType, WalletType, RefCode, TableID,
			Product
		)
		EXEC sp_executesql @Sql, N'@RowStart INT, @RowEnd INT', @RowStart, @RowEnd;

		-- bettrans
		IF EXISTS (SELECT TOP(1) 1 FROM #PagingData WHERE TableID = 1)
		BEGIN
			UPDATE p
			SET
				SportType = CASE
								WHEN p.Product IN ('SB') THEN m.sporttype
								WHEN p.Product IN ('Outright') THEN l.sporttype
								ELSE 0
							END,
				BetTeam = CASE
								WHEN p.Product IN ('SB', 'Parlay') THEN p.BetTeam
								ELSE ''
							END,
				Hdp1 = CASE
							WHEN p.Product IN ('SB', 'Parlay') THEN p.Hdp1
							ELSE 0
						END,
				Hdp2 = CASE
							WHEN p.Product IN ('SB', 'Parlay') THEN p.Hdp2
							ELSE 0
						END,
				OddsType = CASE
							WHEN p.Product IN ('SB', 'Outright') THEN p.OddsType
							ELSE 0
						END,
				Odds = CASE
							WHEN p.Product IN ('SB', 'Outright', 'Parlay') THEN p.Odds
							ELSE 0
						END,
				MOdds = CASE 
							WHEN p.Product IN ('SB', 'Outright', 'Parlay')  THEN p.modds 
							ELSE 0
						END,
				SettlementStatus = CASE
									WHEN p.Product = 'SB' THEN ISNULL(m.SettlementStatus, 0)
									ELSE 0
								END,
				LiveIndicator = CASE
									WHEN p.Product IN ('SB') THEN p.liveindicator
									ELSE 0
								END,
				LiveHomeScore = CASE
									WHEN p.Product IN ('SB', 'Outright', 'Parlay') THEN p.livehomescore
									ELSE 0
								END,
				LiveAwayScore = CASE
									WHEN p.Product IN ('SB', 'Outright') THEN p.liveawayscore
									ELSE 0
								END,
				LeagueId = CASE
								WHEN p.Product IN ('SB') THEN m.leagueid
								WHEN p.Product IN ('Outright') THEN o.leagueid
								ELSE 0
							END,
				MatchId = CASE
								WHEN p.Product IN ('SB') THEN m.matchid
								ELSE 0
							END,
				MatchCode = CASE
								WHEN p.Product IN ('SB') THEN m.matchcode
								ELSE ''
							END,
				EventDate = CASE
							WHEN p.Product IN ('SB', 'CO') THEN m.GlobalShowTime
							ELSE p.WinLostDate
						END,
				HomeId = CASE
							WHEN p.Product IN ('SB') THEN m.homeid
							WHEN p.Product IN ('Outright') THEN o.teamid
							ELSE 0
						END,
				AwayId = CASE
							WHEN p.Product IN ('SB') THEN m.awayid
							ELSE 0
						END,
				BetStatus = CASE
								WHEN p.Product IN ('SB') THEN m.betstatus
								ELSE ''
							END,
				IsNeutral = CASE
								WHEN p.Product IN ('SB') THEN ISNULL(m.IsNeutral, 0)
								ELSE 0
							END,
				BetCheck = CASE
								WHEN p.Product IN ('SB', 'Parlay') THEN ISNULL(p.betcheck, '')
								ELSE ''
							END,
				TransDesc = CASE
								WHEN p.Product IN ('SB') THEN ISNULL(p.transdesc, '')
								WHEN p.bettype = 29 AND p.OddsSpread = 3 THEN ISNULL(p.transdesc, '')
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
				ExtraInfo = CASE
								WHEN p.Product IN ('SB', 'Parlay', 'Outright') THEN ISNULL(p.ExtraInfo, '')
								ELSE ''
							END,
				OriginalStake = CASE
									WHEN p.Product IN ('SB') AND p.ExtraInfo LIKE '%p25%' THEN
										ISNULL(CAST(('<xml>' + p.ExtraInfo + '</xml>') AS XML).value('data(/xml/p25/@s)[1]','MONEY'), 0)
									ELSE 0
								END,
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
							END
			FROM #PagingData AS p
				LEFT JOIN dbo.match AS m WITH (NOLOCK) ON p.Product IN ('SB') AND p.matchid = m.matchid
				LEFT JOIN dbo.outright AS o WITH (NOLOCK) ON p.Product IN ('Outright') AND p.matchid = o.orid
				LEFT JOIN dbo.League AS l WITH (NOLOCK) ON p.Product IN ('Outright') AND o.leagueID = l.leagueID
			WHERE p.TableID = 1
		END

		-- bettrans14
		IF EXISTS (SELECT TOP(1) 1 FROM #PagingData WHERE TableID = 2)
		BEGIN
			UPDATE p14
			SET
				SportType = CASE
								WHEN p14.Product IN ('SB') THEN m.sporttype
								WHEN p14.Product IN ('Outright') THEN l.sporttype
								ELSE 0
							END,
				BetTeam = CASE
								WHEN p14.Product IN ('SB', 'Parlay') THEN p14.BetTeam
								ELSE ''
							END,
				Hdp1 = CASE
							WHEN p14.Product IN ('SB', 'Parlay') THEN p14.Hdp1
							ELSE 0
						END,
				Hdp2 = CASE
							WHEN p14.Product IN ('SB', 'Parlay') THEN p14.Hdp2
							ELSE 0
						END,
				OddsType = CASE
							WHEN p14.Product IN ('SB', 'Outright') THEN p14.OddsType
							ELSE 0
						END,
				Odds = CASE
							WHEN p14.Product IN ('SB', 'Outright', 'Parlay') THEN p14.Odds
							ELSE 0
						END,
				MOdds = CASE 
							WHEN p14.Product IN ('SB', 'Outright', 'Parlay')  THEN p14.modds 
							ELSE 0
						END,
				SettlementStatus = 0,
				LiveIndicator = CASE
									WHEN p14.Product IN ('SB') THEN p14.liveindicator
									ELSE 0
								END,
				LiveHomeScore = CASE
									WHEN p14.Product IN ('SB', 'Outright', 'Parlay') THEN p14.livehomescore
									ELSE 0
								END,
				LiveAwayScore = CASE
									WHEN p14.Product IN ('SB', 'Outright') THEN p14.liveawayscore
									ELSE 0
								END,
				LeagueId = CASE
								WHEN p14.Product IN ('SB') THEN m.leagueid
								WHEN p14.Product IN ('Outright') THEN o.leagueid
								ELSE 0
							END,
				MatchId = CASE
								WHEN p14.Product IN ('SB') THEN m.matchid
								ELSE 0
							END,
				MatchCode = CASE
								WHEN p14.Product IN ('SB') THEN m.matchcode
								ELSE ''
							END,
				EventDate = CASE
							WHEN p14.Product IN ('SB', 'CO') THEN m.GlobalShowTime
							ELSE p14.WinLostDate
						END,
				HomeId = CASE
							WHEN p14.Product IN ('SB') THEN m.homeid
							WHEN p14.Product IN ('Outright') THEN o.teamid
							ELSE 0
						END,
				AwayId = CASE
							WHEN p14.Product IN ('SB') THEN m.awayid
							ELSE 0
						END,
				BetStatus = CASE
								WHEN p14.Product IN ('SB') THEN m.betstatus
								ELSE ''
							END,
				IsNeutral = CASE
								WHEN p14.Product IN ('SB') THEN ISNULL(m.IsNeutral, 0)
								ELSE 0
							END,
				BetCheck = CASE
								WHEN p14.Product IN ('SB', 'Parlay') THEN ISNULL(p14.betcheck, '')
								ELSE ''
							END,
				TransDesc = CASE
								WHEN p14.Product IN ('SB') THEN ISNULL(p14.transdesc, '')
								WHEN p14.bettype = 29 AND p14.OddsSpread = 3 THEN ISNULL(p14.transdesc, '')
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
				ExtraInfo = CASE
								WHEN p14.Product IN ('SB', 'Parlay', 'Outright') THEN ISNULL(p14.ExtraInfo, '')
								ELSE ''
							END,
				OriginalStake = CASE
									WHEN p14.Product IN ('SB') AND p14.ExtraInfo LIKE '%p25%' THEN
										ISNULL(CAST(('<xml>' + p14.ExtraInfo + '</xml>') AS XML).value('data(/xml/p25/@s)[1]','MONEY'), 0)
									ELSE 0
								END,
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
							END
			FROM #PagingData AS p14
				LEFT JOIN dbo.match14 AS m WITH (NOLOCK) ON p14.Product IN ('SB') AND p14.matchid = m.matchid
				LEFT JOIN dbo.outright14 AS o WITH (NOLOCK) ON p14.Product IN ('Outright') AND p14.matchid = o.orid
				LEFT JOIN dbo.League AS l WITH (NOLOCK) ON p14.Product IN ('Outright') AND o.leagueID = l.leagueID
			WHERE p14.TableID = 2
		END

		-- bettrans_bk
		IF EXISTS (SELECT TOP(1) 1 FROM #PagingData WHERE TableID = 3)
		BEGIN
			UPDATE pbk
			SET
				SportType = CASE
								WHEN pbk.Product IN ('SB') THEN m.sporttype
								WHEN pbk.Product IN ('Outright') THEN l.sporttype
								ELSE 0
							END,
				BetTeam = CASE
								WHEN pbk.Product IN ('SB', 'Parlay') THEN pbk.BetTeam
								ELSE ''
							END,
				Hdp1 = CASE
							WHEN pbk.Product IN ('SB', 'Parlay') THEN pbk.Hdp1
							ELSE 0
						END,
				Hdp2 = CASE
							WHEN pbk.Product IN ('SB', 'Parlay') THEN pbk.Hdp2
							ELSE 0
						END,
				OddsType = CASE
							WHEN pbk.Product IN ('SB', 'Outright') THEN pbk.OddsType
							ELSE 0
						END,
				Odds = CASE
							WHEN pbk.Product IN ('SB', 'Outright', 'Parlay') THEN pbk.Odds
							ELSE 0
						END,
				MOdds = CASE 
							WHEN pbk.Product IN ('SB', 'Outright', 'Parlay')  THEN pbk.modds 
							ELSE 0
						END,
				SettlementStatus = 0,
				LiveIndicator = CASE
									WHEN pbk.Product IN ('SB') THEN pbk.liveindicator
									ELSE 0
								END,
				LiveHomeScore = CASE
									WHEN pbk.Product IN ('SB', 'Outright', 'Parlay') THEN pbk.livehomescore
									ELSE 0
								END,
				LiveAwayScore = CASE
									WHEN pbk.Product IN ('SB', 'Outright') THEN pbk.liveawayscore
									ELSE 0
								END,
				LeagueId = CASE
								WHEN pbk.Product IN ('SB') THEN m.leagueid
								WHEN pbk.Product IN ('Outright') THEN o.leagueid
								ELSE 0
							END,
				MatchId = CASE
								WHEN pbk.Product IN ('SB') THEN m.matchid
								ELSE 0
							END,
				MatchCode = CASE
								WHEN pbk.Product IN ('SB') THEN m.matchcode
								ELSE ''
							END,
				EventDate = CASE
							WHEN pbk.Product IN ('SB', 'CO') THEN m.GlobalShowTime
							ELSE pbk.WinLostDate
						END,
				HomeId = CASE
							WHEN pbk.Product IN ('SB') THEN m.homeid
							WHEN pbk.Product IN ('Outright') THEN o.teamid
							ELSE 0
						END,
				AwayId = CASE
							WHEN pbk.Product IN ('SB') THEN m.awayid
							ELSE 0
						END,
				BetStatus = CASE
								WHEN pbk.Product IN ('SB') THEN m.betstatus
								ELSE ''
							END,
				IsNeutral = CASE
								WHEN pbk.Product IN ('SB') THEN ISNULL(m.IsNeutral, 0)
								ELSE 0
							END,
				BetCheck = CASE
								WHEN pbk.Product IN ('SB', 'Parlay') THEN ISNULL(pbk.betcheck, '')
								ELSE ''
							END,
				TransDesc = CASE
								WHEN pbk.Product IN ('SB') THEN ISNULL(pbk.transdesc, '')
								WHEN pbk.bettype = 29 AND pbk.OddsSpread = 3 THEN ISNULL(pbk.transdesc, '')
								ELSE ''
							END,
				OddsSpread = CASE
								WHEN pbk.Product IN ('SB') THEN ISNULL(pbk.oddsspread, 0)
								ELSE 0
							END,
				BetdaqId = CASE
								WHEN pbk.Product IN ('SB') THEN ISNULL(pbk.betdaqid, -1)
								ELSE -1
							END,
				ExtraInfo = CASE
								WHEN pbk.Product IN ('SB', 'Parlay', 'Outright') THEN ISNULL(pbk.ExtraInfo, '')
								ELSE ''
							END,
				OriginalStake = CASE
									WHEN pbk.Product IN ('SB') AND pbk.ExtraInfo LIKE '%p25%' THEN
										ISNULL(CAST(('<xml>' + pbk.ExtraInfo + '</xml>') AS XML).value('data(/xml/p25/@s)[1]','MONEY'), 0)
									ELSE 0
								END,
				OriginalBetType = CASE
									WHEN pbk.Product IN ('SB') AND pbk.stake <> 0 THEN -1
									ELSE 0
								END,
				WalletType = CASE
								WHEN pbk.Product IN ('SB') THEN ISNULL(pbk.WalletType, 0)
								ELSE 0
							END,
				RefCode = CASE
								WHEN pbk.Product IN ('SB') AND pbk.stake <> 0 THEN ISNULL(pbk.RefCode, 0)
								ELSE 0
							END
			FROM #PagingData AS pbk
				LEFT JOIN bodb_Archive.dbo.match_bk AS m WITH (NOLOCK) ON pbk.Product IN ('SB') AND pbk.matchid = m.matchid
				LEFT JOIN bodb_Archive.dbo.outright_bk AS o WITH (NOLOCK) ON pbk.Product IN ('Outright') AND pbk.matchid = o.orid
				LEFT JOIN dbo.League AS l WITH (NOLOCK) ON pbk.Product IN ('Outright') AND o.leagueID = l.leagueID
			WHERE pbk.TableID = 3
		END
	END

	-- Return data
	SELECT
		c.username,
		SUBSTRING(c.username2,  CHARINDEX('$', c.username2) + 1, LEN(c.username2) - CHARINDEX('$', c.username2)) AS Nickname,
		p.TransId,
		p.RefNo,
		p.BetId,
		p.CustId,
		p.TransDate,
		p.WinLostDate,
		p.SportType,
		p.BetType,
		p.BetTeam,
		p.Hdp1,
		p.Hdp2,
		p.Odds,
		p.MOdds,
		p.OddsType,
		p.OddsSpread,
		p.Status,
		p.SettlementStatus,
		p.LiveIndicator,
		p.LiveHomeScore,
		p.LiveAwayScore,
		p.LeagueId,
		p.MatchId,
		p.MatchCode,
		p.EventDate,
		p.HomeId,
		p.AwayId,
		p.IsNeutral,
		p.BetStatus,
		p.Currency,
		p.Stake * ISNULL(e.Rate, 1) AS Stake,
		p.Actual_Stake * ISNULL(e.Rate, 1) AS Actual_Stake,
		p.WinLost * ISNULL(e.Rate, 1) AS WinLost,
		p.LicenseeWL * ISNULL(e.Rate, 1) AS LicenseeWL,
		p.Comm * ISNULL(e.Rate, 1) AS Comm,
		p.PlayerComm * ISNULL(e.Rate, 1) AS PlayerComm,
		p.Ip,
		p.BetCheck,
		p.TransDesc,
		p.BetdaqId,
		p.ExtraInfo,
		p.OriginalStake * ISNULL(e.Rate, 1) AS OriginalStake,
		p.OriginalBetType,
		p.WalletType,
		p.RefCode
	FROM
		#PagingData AS p
		INNER JOIN dbo.Customer AS c WITH (NOLOCK) ON p.CustId = c.custid
		LEFT JOIN #ExchangeRate AS e ON p.WinLostDate BETWEEN e.FirstExchangeDateByMonth AND e.LastExchangeDateByMonth
	ORDER BY p.RowNum ASC

	DROP TABLE #Data
	DROP TABLE #PagingData
	DROP TABLE #ExchangeRate
	DROP TABLE #Tickets
END
GO
