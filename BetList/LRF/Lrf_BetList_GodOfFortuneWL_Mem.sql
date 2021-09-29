/*<info serverAlias="DBACC-bodb02" executers="bodbLicenseeNet" viewers="" isFunction="0" isNested="0"></info>*/

ALTER PROCEDURE [dbo].[Lrf_BetList_GodOfFortuneWL_Mem]
	@AgentList			VARCHAR(MAX),
	@CustId				INT,
	@FromDate			SMALLDATETIME,
	@ToDate				SMALLDATETIME,
	@MoveBetsDay		SMALLDATETIME,
	@BalanceUpDay		SMALLDATETIME,
	@DrawFilter			TINYINT			= 1,
	@BaseCurrency		VARCHAR(10),
	@PageSize			INT				= 1000,
	@PageIndex			INT				= 1,
	@TotalRows			INT				= 0 OUTPUT,
	@SumWinLost			MONEY			= 0 OUTPUT,
	@SumLicenseeWL		MONEY			= 0 OUTPUT,
	@SumComm			MONEY			= 0 OUTPUT,
	@SumPlayerComm		MONEY			= 0 OUTPUT
AS

/*
	Created: 20200413@Kos
	Task: LAP - Bet list of God Of Fortune WL report
	DB: DBACC.bodb02

	Revisions:
		- 20200413@Kos: Support God Of Fortune WL report [Redmine: #152900]
		- 20210929@Kos: Extend length to support IPv6 [Redmine: 162342]
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
		BetType				SMALLINT,
		BetId				BIGINT,
		BetTeam				NVARCHAR(20),
		Hdp1				SMALLMONEY,
		Hdp2				SMALLMONEY,
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
		TransDate			DATETIME,
		WinLostDate			SMALLDATETIME,
		LiveHomeScore		SMALLINT,
		Ip					VARCHAR(45),
		BetCheck			NVARCHAR(50),
		ExtraInfo			VARCHAR(1000),
		TableID				TINYINT
	)

	CREATE TABLE #PagingData (
		RowNum				INT,
		TransId				BIGINT,
		RefNo				BIGINT,
		CustId				INT,
		Currency			SMALLINT,
		Recommend			INT,
		BetType				SMALLINT,
		BetId				BIGINT,
		BetTeam				NVARCHAR(20),
		Hdp1				SMALLMONEY,
		Hdp2				SMALLMONEY,
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
		TransDate			DATETIME,
		WinLostDate			SMALLDATETIME,
		LiveHomeScore		SMALLINT,
		Ip					VARCHAR(45),
		BetCheck			NVARCHAR(50),
		ExtraInfo			VARCHAR(1000),
		TableID				TINYINT
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
		DECLARE @TempToDate	SMALLDATETIME,
			@TempFromDate	SMALLDATETIME

		-- bettrans
		IF @ToDate > @MoveBetsDay
		BEGIN
			SET @TempFromDate = CASE
									WHEN @FromDate <= @MoveBetsDay THEN DATEADD(DAY, 1, @MoveBetsDay)
									ELSE @FromDate
								END

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
				LiveHomeScore,
				Ip,
				BetCheck,
				ExtraInfo,
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
				b.livehomescore,
				b.ip,
				b.betcheck,
				b.ExtraInfo,
				1 AS TableID
			FROM dbo.bettrans AS b WITH (NOLOCK, INDEX = IX_custid)
			WHERE b.custid = @CustId
				AND b.winlostdate BETWEEN @TempFromDate AND @ToDate
				AND b.statusID IN (111, 112, 113)
				AND b.bettype = 29
				AND b.oddsspread = 1
		END

		-- bettrans14
		IF @FromDate <= @MoveBetsDay AND @ToDate >= @BalanceUpDay
		BEGIN
			SET @TempToDate = CASE
								WHEN @ToDate >= @MoveBetsDay THEN @MoveBetsDay
								ELSE @ToDate
							END
			SET @TempFromDate = CASE
									WHEN @FromDate < @BalanceUpDay THEN @BalanceUpDay
									ELSE @FromDate
								END

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
				LiveHomeScore,
				Ip,
				BetCheck,
				ExtraInfo,
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
				b.livehomescore,
				b.ip,
				b.betcheck,
				b.ExtraInfo,
				2 AS TableID
			FROM dbo.bettrans14 AS b WITH (NOLOCK, INDEX = IX_memberStatement14)
			WHERE b.custid = @CustId
				AND b.winlostdate BETWEEN @TempFromDate AND @TempToDate
				AND b.statusID IN (111, 112, 113)
				AND b.bettype = 29
				AND b.oddsspread = 1
		END

		-- bettrans_bk
		IF @FromDate <= @BalanceUpDay
		BEGIN
			SET @TempToDate = CASE
								WHEN @ToDate >= DATEADD(dd, -1, @BalanceUpDay) THEN DATEADD(dd, -1, @BalanceUpDay)
								ELSE @ToDate
							END

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
				LiveHomeScore,
				Ip,
				BetCheck,
				ExtraInfo,
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
				b.livehomescore,
				b.ip,
				b.betcheck,
				b.ExtraInfo,
				3 AS TableID
			FROM bodb_Archive.dbo.bettrans_bk AS b WITH (NOLOCK, INDEX = IX_custid)
			WHERE b.custid = @CustId
				AND b.winlostdate BETWEEN @FromDate AND @TempToDate
				AND b.statusID IN (111, 112, 113)
				AND b.bettype = 29
				AND b.oddsspread = 1
		END

		DELETE b
		FROM #Data AS b
		WHERE NOT EXISTS (SELECT 1 FROM @TempAg WHERE CustId = b.Recommend AND Currency = b.Currency)
			OR (@DrawFilter = 2
				AND b.Status = 'DRAW'
				AND ABS(b.MOdds) <> 0.25)

		IF EXISTS (SELECT TOP(1) 1 FROM #Data)
		BEGIN
			UPDATE #Data
			SET
				WinLost = WinLost - Actual_Stake,
				LicenseeWL = - (WinLost - Actual_Stake)

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
				WHERE e.ExchangeId = @Currency
					AND EXISTS (SELECT 1 FROM #Data WHERE WinLostDate BETWEEN e.FirstExchangeDateByMonth AND e.LastExchangeDateByMonth)
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
					TransId = CASE
								WHEN ISNULL(b.BetId, 0) > 0 THEN b.BetId
								ELSE b.TransId
							END
				FROM #PagingData AS b
				WHERE b.TableID = 1
			END

			-- bettrans14
			IF EXISTS (SELECT TOP(1) 1 FROM #PagingData WHERE TableID = 2)
			BEGIN
				UPDATE b
				SET
					TransId = CASE
								WHEN ISNULL(b.BetId, 0) > 0 THEN b.BetId
								ELSE b.TransId
							END
				FROM #PagingData AS b
				WHERE b.TableID = 2
			END

			-- bettrans_bk
			IF EXISTS (SELECT TOP(1) 1 FROM #PagingData WHERE TableID = 3)
			BEGIN
				UPDATE b
				SET
					TransId = CASE
								WHEN ISNULL(b.BetId, 0) > 0 THEN b.BetId
								ELSE b.TransId
							END
				FROM #PagingData AS b
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
		a.BetType,
		a.BetTeam,
		a.Hdp1,
		a.Hdp2,
		a.Odds,
		a.MOdds,
		a.Status,
		a.LiveHomeScore,
		a.Currency,
		a.Stake * ISNULL(e.Rate, 1) AS Stake,
		a.Actual_Stake * ISNULL(e.Rate, 1) AS Actual_Stake,
		a.WinLost * ISNULL(e.Rate, 1) AS WinLost,
		a.LicenseeWL * ISNULL(e.Rate, 1) AS LicenseeWL,
		a.Comm * ISNULL(e.Rate, 1) AS Comm,
		a.PlayerComm * ISNULL(e.Rate, 1) AS PlayerComm,
		a.Ip,
		a.BetCheck,
		a.ExtraInfo
	FROM
		#PagingData AS a
		LEFT JOIN #ExchangeRate AS e ON a.WinLostDate BETWEEN e.FirstExchangeDateByMonth AND e.LastExchangeDateByMonth
	ORDER BY a.RowNum ASC

	DROP TABLE #PagingData
	DROP TABLE #ExchangeRate
END
GO
