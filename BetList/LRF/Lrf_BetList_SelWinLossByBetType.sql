/*<info serverAlias="DBEXT-bodb02" executers="bodbLicenseeNet" viewers="" isFunction="0" isNested="0"></info>*/

ALTER PROCEDURE [dbo].[Lrf_BetList_SelWinLossByBetType]
	@AgentList		VARCHAR(MAX),
	@BetType		INT,
	@FromDate		SMALLDATETIME,
	@ToDate			SMALLDATETIME,
	@MoveBetsDay	SMALLDATETIME,
	@BalanceUpDay	SMALLDATETIME,
	@BaseCurrency	VARCHAR(10),
	@PageSize		INT				= 1000,
	@PageIndex		INT				= 1,
	@Sort			NVARCHAR(50)	= N'TransDate ASC',
	@TotalRows		INT				= 0 OUTPUT,
	@SumWinLost		MONEY			= 0 OUTPUT,
	@SumLicenseeWL	MONEY			= 0 OUTPUT,
	@SumComm		MONEY			= 0 OUTPUT,
	@SumPlayerComm	MONEY			= 0 OUTPUT
AS

/*
	Created: Kos@20160229
	Task: Get bet list of Win Loss By Bet Type report
	DB: DBEXT.bodb02
	Original:
	Revisions:
		- 20160414@Kos: Support Combo Parlay [#Redmine: 55282]
		- 20160531@Kos: Add sorting function [#Redmine: 58491]
		- 20160721@Percy: Enhance Performance - using index recommend on bettrans/bettrans14 [RedmineID: #60770]
		- 20160801@Kos: Exclude bet type 904 [#Redmine: 58978]
		- 20161005@Kos: Add product bet type range for sub tickets [Redmine: #65045]
		- 20170227@Kos: Support sub licensees [#Redmine: 71679]
		- 20170302@Kos: Support KickOffTime for Virtual Soccer and Virtual Tennis [#Redmine: 71906]
		- 20170327@Kos: Support CashOut [#Redmine: 71963]
		- 20170620@Kos: Support Betradar Virtual Sports [#Redmine: 77280]
		- 20170726@Kos: Support Keno Lottery [#Redmine: 79997]
		- 20170905@Kos: Support Licensee Bonus System [#Redmine: 72792]
		- 20180305@Kos: Don't support Live Casino anymore [#Redmine: 85965]
		- 20180327@Kos: Increase TransDesc length to 1000 [#Redmine: 92433]
		- 20180329@Kos: Support Fast Market 2 [#Redmine: 90879]
		- 20180409@Kos: Support Betradar Virtual Basketball [Redmine: #90881]
		- 20180510@Kos: Support Keno 6 new Mini Games [#Redmine: 94829]
		- 20180806@Kos: Don't support Racing anymore [#Redmine: 99378]
		- 20181227@Kos: Hotfix - Licensee WL/Comm on BA ticket [#Redmine: 107084]
		- 20190509@Kos: Show match KO time for single ticket [Redmine: #112731]
					- Return additional column EventDate DATETIME
		- 20190521@Kos: Add new input param @BaseCurrency [#Redmine: 112531]
					- Change input param @Sort data type from VARCHAR(100) to NVARCHAR(50)
					- Remove params @SumWinLostUSD, @SumWinLostEUR, @SumWinLostGBP, ...
		- 20190715@Kos: Hotfix - Error in sorting [#Redmine: 116889]
		- 20200207@Kos: Support sort by trans time [Redmine: #126886]
		- 20200402@Kos: Support Table Games [Redmine: #131447]
		- 20200416@Kos: Support Indo 4D [Redmine: #130859]
		- 20200425@Kos: Support status Delay Payout [Redmine: #132629]
*/

BEGIN
	SET NOCOUNT ON

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
		SELECT ErrCode = 100,
			ErrMsg = N'Parameter invalid.'

		RETURN
	END CATCH

	-- Sport Bet Type matrix
	DECLARE @SportBettype TABLE(ProductId TINYINT, Bettype SMALLINT, EventType TINYINT)

	DECLARE @IsTest BIT

	SELECT @IsTest = dbo.f_CheckSPVersion(@@PROCID)

	INSERT INTO @SportBettype
	SELECT DISTINCT ProductId, Bettype, EventType
	FROM dbo.f_SportBettypeMatrix_Sel(0, 0, 0, 2, '', '', @IsTest)
	WHERE
		ProductID IN (1, 3, 5, 8, 27, 28, 40, 43)
		AND Bettype NOT IN (901, 902, 903, 904, 911, 912, 913, 914)
		AND BetType IN (
			SELECT Bettype FROM dbo.f_GroupBettype() WHERE GroupTypeId = @BetType
			UNION SELECT GroupTypeId FROM dbo.f_GroupBettype() WHERE Bettype = @BetType
			UNION SELECT Bettype FROM dbo.f_GroupBetType3rd() WHERE GroupTypeId = @BetType
			UNION SELECT GroupTypeId FROM dbo.f_GroupBetType3rd() WHERE Bettype = @BetType
			UNION SELECT @BetType)

	-- Create temp table
	CREATE TABLE #AllData (
		TransId			BIGINT,
		RefNo			BIGINT,
		Recommend		INT,
		Currency		SMALLINT,
		TransDate		DATETIME,
		WinLostDate		DATETIME,
		Stake			MONEY,
		Actual_Stake	MONEY,
		WinLost			MONEY,
		LicenseeWL		MONEY,
		Comm			MONEY,
		PlayerComm		MONEY,
		WalletType		TINYINT,
		RefCode			BIGINT,
		WhTicket		TINYINT
	)

	CREATE TABLE #TempData (
		RowNum			INT,
		TransId			BIGINT,
		RefNo			BIGINT,
		Stake			MONEY,
		Actual_Stake	MONEY,
		WinLost			MONEY,
		LicenseeWL		MONEY,
		Comm			MONEY,
		PlayerComm		MONEY,
		WalletType		TINYINT,
		RefCode			BIGINT,
		WhTicket		TINYINT
	)

	CREATE TABLE #Data (
		RowNum				INT,
		TransId				BIGINT,
		RefNo				BIGINT,
		BetId				BIGINT,
		CustId				INT,
		Username			NVARCHAR(50),
		SportType			INT,
		BetType				INT,
		Currency			SMALLINT,
		LeagueId			INT,
		MatchId				INT,
		MatchCode			VARCHAR(50),
		EventDate			DATETIME,
		IsNeutral			BIT,
		HomeId				INT,
		AwayId				INT,
		Hdp1				SMALLMONEY,
		Hdp2				SMALLMONEY,
		BetTeam				NVARCHAR(10),
		Odds				MONEY,
		OddsType			TINYINT,
		Modds				MONEY,
		LiveIndicator		BIT,
		LiveHomeScore		SMALLINT,
		LiveAwayScore		SMALLINT,
		ShowTime			NVARCHAR(50),
		Status				NVARCHAR(10),
		SettlementStatus	TINYINT,
		BetStatus			NVARCHAR(50),
		TransDate			DATETIME,
		WinLostDate			DATETIME,
		Stake				MONEY,
		Actual_Stake		MONEY,
		WinLost				MONEY,
		LicenseeWL			MONEY,
		Comm				MONEY,
		PlayerComm			MONEY,
		Race				VARCHAR(20),
		BetCheck			NVARCHAR(50),
		TransDesc			NVARCHAR(1000),
		BetdaqId			BIGINT,
		ExtraInfo			VARCHAR(1000),
		OriginalStake		MONEY,
		OriginalBetType		SMALLINT,
		WalletType			TINYINT,
		RefCode				BIGINT,
		OddsSpread			MONEY
	)

	CREATE TABLE #ExchangeRate (
		ExchangeId					INT,
		FirstExchangeDateByMonth	SMALLDATETIME,
		LastExchangeDateByMonth		SMALLDATETIME,
		Rate						FLOAT
	)

	DECLARE @TempFromDate DATETIME,
		@TempToDate DATETIME

	-- Bettrans range
	IF @ToDate > @MoveBetsDay
	BEGIN
		IF @FromDate <= @MoveBetsDay
			SET @TempFromDate = DATEADD(DAY, 1, @MoveBetsDay)
		ELSE
			SET @TempFromDate = @FromDate

		IF EXISTS (SELECT 1 FROM dbo.f_GroupBettype() WHERE Bettype = @BetType)
				OR EXISTS (SELECT 1 FROM dbo.f_GroupBettype() WHERE GroupTypeId = @BetType)
		BEGIN
			INSERT INTO #AllData
			SELECT
				b.transid,
				b.refno,
				b.recommend,
				b.currency,
				b.transdate,
				b.winlostdate,
				b.stake,
				b.actual_stake,
				(b.winlost - b.actual_stake) AS WinLost,
				CASE
					WHEN s.ProductID = 1 AND b.tpositiontaking = 0 THEN 0
					ELSE -(b.winlost - b.actual_stake)
				END AS LicenseeWL,
				b.comm,
				b.playercomm,
				CASE
					WHEN s.ProductID = 1 THEN ISNULL(b.WalletType, 0)
					ELSE 0
				END AS WalletType,
				CASE
					WHEN s.ProductID = 1 THEN ISNULL(b.RefCode, 0)
					ELSE 0
				END AS RefCode,
				1 AS WhTicket -- bettrans
			FROM
				dbo.bettrans AS b WITH (NOLOCK)
				INNER JOIN @TempAg AS t ON b.recommend = t.CustId
				INNER JOIN @SportBettype AS s ON b.bettype = s.Bettype
				LEFT JOIN dbo.f_GroupBettype() AS ss ON b.bettype = ss.Bettype
			WHERE
				b.winlostdate BETWEEN @TempFromDate AND @ToDate
				AND CASE WHEN ss.Bettype IS NULL THEN b.bettype ELSE ss.GroupTypeId END = @BetType
				AND b.statusID IN (111, 112, 113)
		END
		ELSE IF EXISTS (SELECT 1 FROM dbo.f_GroupBetType3rd() WHERE Bettype = @BetType)
				OR EXISTS (SELECT 1 FROM dbo.f_GroupBetType3rd() WHERE GroupTypeId = @BetType)
		BEGIN
			INSERT INTO #AllData
			SELECT
				b.transid,
				b.refno,
				b.recommend,
				b.currency,
				b.transdate,
				b.winlostdate,
				b.stake,
				b.actual_stake,
				(b.winlost - b.actual_stake) AS WinLost,
				CASE
					WHEN s.ProductID = 1 AND b.tpositiontaking = 0 THEN 0
					ELSE -(b.winlost - b.actual_stake)
				END AS LicenseeWL,
				b.comm,
				b.playercomm,
				CASE
					WHEN s.ProductID = 1 THEN ISNULL(b.WalletType, 0)
					ELSE 0
				END AS WalletType,
				CASE
					WHEN s.ProductID = 1 THEN ISNULL(b.RefCode, 0)
					ELSE 0
				END AS RefCode,
				1 AS WhTicket -- bettrans
			FROM
				dbo.bettrans AS b WITH (NOLOCK)
				INNER JOIN @TempAg AS t ON b.recommend = t.CustId
				INNER JOIN @SportBettype AS s ON b.bettype = s.Bettype
				LEFT JOIN dbo.f_GroupBettype3rd() AS ss ON b.bettype = ss.Bettype
			WHERE
				b.winlostdate BETWEEN @TempFromDate AND @ToDate
				AND CASE WHEN ss.Bettype IS NULL THEN b.bettype ELSE ss.GroupTypeId END = @BetType
				AND b.statusID IN (111, 112, 113)
		END
		ELSE
		BEGIN
			INSERT INTO #AllData
			SELECT
				b.transid,
				b.refno,
				b.recommend,
				b.currency,
				b.transdate,
				b.winlostdate,
				b.stake,
				b.actual_stake,
				(b.winlost - b.actual_stake) AS WinLost,
				CASE
					WHEN s.ProductID = 1 AND b.tpositiontaking = 0 THEN 0
					ELSE -(b.winlost - b.actual_stake)
				END AS LicenseeWL,
				b.comm,
				b.playercomm,
				CASE
					WHEN s.ProductID = 1 THEN ISNULL(b.WalletType, 0)
					ELSE 0
				END AS WalletType,
				CASE
					WHEN s.ProductID = 1 THEN ISNULL(b.RefCode, 0)
					ELSE 0
				END AS RefCode,
				1 AS WhTicket -- bettrans
			FROM
				dbo.bettrans AS b WITH (NOLOCK)
				INNER JOIN @TempAg AS t ON b.recommend = t.CustId
				INNER JOIN @SportBettype AS s ON b.bettype = s.Bettype
			WHERE
				b.winlostdate BETWEEN @TempFromDate AND @ToDate
				AND b.bettype = @BetType
				AND b.statusID IN (111, 112, 113)
		END
	END

	-- Bettrans14 range
	IF @FromDate <= @MoveBetsDay
	BEGIN
		IF @ToDate >= @MoveBetsDay
			SET @TempToDate = @MoveBetsDay
		ELSE
			SET @TempToDate = @ToDate

		IF @BalanceUpDay < @FromDate
			SELECT @BalanceUpDay = @FromDate

		IF EXISTS (SELECT 1 FROM dbo.f_GroupBettype() WHERE Bettype = @BetType)
				OR EXISTS (SELECT 1 FROM dbo.f_GroupBettype() WHERE GroupTypeId = @BetType)
		BEGIN
			INSERT INTO #AllData
			SELECT
				b.transid,
				b.refno,
				b.recommend,
				b.currency,
				b.transdate,
				b.winlostdate,
				b.stake,
				b.actual_stake,
				(b.winlost - b.actual_stake) AS WinLost,
				CASE
					WHEN s.ProductID = 1 AND b.tpositiontaking = 0 THEN 0
					ELSE -(b.winlost - b.actual_stake)
				END AS LicenseeWL,
				b.comm,
				b.playercomm,
				CASE
					WHEN s.ProductID = 1 THEN ISNULL(b.WalletType, 0)
					ELSE 0
				END AS WalletType,
				CASE
					WHEN s.ProductID = 1 THEN ISNULL(b.RefCode, 0)
					ELSE 0
				END AS RefCode,
				2 AS WhTicket -- bettrans14
			FROM
				dbo.bettrans14 b WITH (NOLOCK)
				INNER JOIN @TempAg AS t ON b.recommend = t.CustId
				INNER JOIN @SportBettype AS s ON b.bettype = s.Bettype
				LEFT JOIN dbo.f_GroupBettype() AS ss ON b.bettype = ss.Bettype
			WHERE
				b.winlostdate BETWEEN @BalanceUpDay AND @TempToDate
				AND CASE WHEN ss.Bettype IS NULL THEN b.bettype ELSE ss.Grouptypeid END = @BetType
				AND b.statusID IN (111, 112, 113)
		END
		ELSE IF EXISTS (SELECT 1 FROM dbo.f_GroupBetType3rd() WHERE Bettype = @BetType)
				OR EXISTS (SELECT 1 FROM dbo.f_GroupBetType3rd() WHERE GroupTypeId = @BetType)
		BEGIN
			INSERT INTO #AllData
			SELECT
				b.transid,
				b.refno,
				b.recommend,
				b.currency,
				b.transdate,
				b.winlostdate,
				b.stake,
				b.actual_stake,
				(b.winlost - b.actual_stake) AS WinLost,
				CASE
					WHEN s.ProductID = 1 AND b.tpositiontaking = 0 THEN 0
					ELSE -(b.winlost - b.actual_stake)
				END AS LicenseeWL,
				b.comm,
				b.playercomm,
				CASE
					WHEN s.ProductID = 1 THEN ISNULL(b.WalletType, 0)
					ELSE 0
				END AS WalletType,
				CASE
					WHEN s.ProductID = 1 THEN ISNULL(b.RefCode, 0)
					ELSE 0
				END AS RefCode,
				2 AS WhTicket -- bettrans14
			FROM
				dbo.bettrans14 AS b WITH (NOLOCK)
				INNER JOIN @TempAg AS t ON b.recommend = t.CustId
				INNER JOIN @SportBettype AS s ON b.bettype = s.Bettype
				LEFT JOIN dbo.f_GroupBetType3rd() AS ss ON b.bettype = ss.Bettype
			WHERE
				b.winlostdate BETWEEN @BalanceUpDay AND @TempToDate
				AND CASE WHEN ss.Bettype IS NULL THEN b.bettype ELSE ss.GroupTypeId END = @BetType
				AND b.statusID IN (111, 112, 113)
		END
		ELSE
		BEGIN
			INSERT INTO #AllData
			SELECT
				b.transid,
				b.refno,
				b.recommend,
				b.currency,
				b.transdate,
				b.winlostdate,
				b.stake,
				b.actual_stake,
				(b.winlost - b.actual_stake) AS WinLost,
				CASE
					WHEN s.ProductID = 1 AND b.tpositiontaking = 0 THEN 0
					ELSE -(b.winlost - b.actual_stake)
				END AS LicenseeWL,
				b.comm,
				b.playercomm,
				CASE
					WHEN s.ProductID = 1 THEN ISNULL(b.WalletType, 0)
					ELSE 0
				END AS WalletType,
				CASE
					WHEN s.ProductID = 1 THEN ISNULL(b.RefCode, 0)
					ELSE 0
				END AS RefCode,
				2 AS WhTicket -- bettrans14
			FROM
				dbo.bettrans14 AS b WITH (NOLOCK)
				INNER JOIN @TempAg AS t ON b.recommend = t.CustId
				INNER JOIN @SportBettype AS s ON b.bettype = s.Bettype
			WHERE
				b.winlostdate BETWEEN @BalanceUpDay AND @TempToDate
				AND b.bettype = @BetType
				AND b.statusID IN (111, 112, 113)
		END
	END

	DELETE b
	FROM #AllData AS b
	WHERE NOT EXISTS (SELECT 1 FROM @TempAg WHERE CustId = b.Recommend AND Currency = b.Currency)

	-- Get data for summary ticket of multiple Bonus/Cash sub tickets
	IF EXISTS (SELECT 1 FROM #AllData WHERE RefCode <> 0)
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
		FROM #AllData
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
			FROM #AllData AS b
				INNER JOIN @RefCodeTmp AS r ON b.RefCode = r.RefCode AND b.TransId = r.TransId

			-- Delete 2nd Bonus/Cash tickets
			DELETE #AllData
			WHERE WalletType <> 0
				AND RefCode IN (SELECT RefCode FROM @RefCodeTmp)
		END
	END

	-- Display detail link for ticket from Bonus Wallet only
	UPDATE #AllData
	SET RefCode = TransId
	WHERE WalletType = 1 AND RefCode = 0

	-- Don't display Cash text for ticket from Cash Wallet only
	UPDATE #AllData
	SET WalletType = 0
	WHERE WalletType = 2 AND RefCode = 0

	-- Get exchange rate
	DECLARE @Today SMALLDATETIME
 
	SET @Today = CONVERT(VARCHAR(10), CURRENT_TIMESTAMP, 120)

	DECLARE @ExFromDate SMALLDATETIME,
		@ExToDate SMALLDATETIME

	SELECT
		@ExFromDate = MIN(WinLostDate),
		@ExToDate = MAX(WinLostDate)
	FROM #AllData

	INSERT INTO #ExchangeRate
	SELECT
		e.ExchangeId,
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
			ELSE 1
		END AS Rate
	FROM dbo.Lrf_f_GetSubExchangeDaily(@ExFromDate, @ExToDate) AS e
	WHERE EXISTS (SELECT 1 FROM #AllData
				WHERE Currency = e.ExchangeId
					AND WinLostDate BETWEEN e.FirstExchangeDateByMonth AND e.LastExchangeDateByMonth)

	-- Get total values
	SELECT
		@TotalRows			= COUNT(b.TransId),
		@SumWinlost			= SUM(b.WinLost		* ISNULL(e.Rate, 1)),
		@SumLicenseeWL		= SUM(b.LicenseeWL	* ISNULL(e.Rate, 1)),
		@SumComm			= SUM(b.Comm		* ISNULL(e.Rate, 1)),
		@SumPlayerComm		= SUM(b.PlayerComm	* ISNULL(e.Rate, 1))
	FROM #AllData AS b
		LEFT JOIN #ExchangeRate AS e
			ON e.ExchangeId = b.Currency
				AND b.WinLostDate BETWEEN e.FirstExchangeDateByMonth AND e.LastExchangeDateByMonth

	-- Exchange rate is different for each day => Stake order may be different from StakeUSD order
	IF @Sort LIKE '%Stake%' OR @Sort LIKE '%WinLost%' OR @Sort LIKE '%LicenseeWL%'
	BEGIN
		DECLARE @CharIndex TINYINT

		SELECT @CharIndex = CHARINDEX(' ', @Sort, 1)

		SELECT @Sort = SUBSTRING(@Sort, 0, @CharIndex) + ' * ISNULL(e.Rate, 1)' + SUBSTRING(@Sort, @CharIndex, LEN(@Sort))
	END

	IF @Sort NOT LIKE '%TransId%'
	BEGIN
		SELECT @Sort = @Sort + ', TransId ASC'
	END

	DECLARE @RowStart	INT,
		@RowEnd			INT

	SELECT @PageIndex = @PageIndex - 1,
		@RowStart = @PageSize * @PageIndex + 1,
		@RowEnd = @RowStart + @PageSize - 1

	DECLARE @Sql NVARCHAR(1000)

	SET @Sql = 
		'DECLARE @Today SMALLDATETIME

		SET @Today = CONVERT(VARCHAR(10), CURRENT_TIMESTAMP, 120)

		SELECT
			tmp.RowNum,
			tmp.TransId,
			tmp.RefNo,
			tmp.Stake,
			tmp.Actual_Stake,
			tmp.WinLost,
			tmp.LicenseeWL,
			tmp.Comm,
			tmp.PlayerComm,
			tmp.WalletType,
			tmp.RefCode,
			tmp.WhTicket
		FROM
		(
			SELECT
				ROW_NUMBER() OVER (ORDER BY ' + @Sort + ') AS RowNum,
				b.* 
			FROM #AllData AS b' +
			CASE
				WHEN @Sort LIKE '%e.Rate%' THEN N'
				LEFT JOIN #ExchangeRate AS e
					ON e.ExchangeId = b.Currency
						AND CASE
								WHEN b.WinLostDate > @Today THEN @Today
								ELSE b.WinLostDate
							END BETWEEN e.FirstExchangeDateByMonth AND e.LastExchangeDateByMonth'
				ELSE N' '
			END + N'
		) AS tmp
		WHERE tmp.RowNum BETWEEN @RowStart AND @RowEnd
		ORDER BY tmp.RowNum'

	INSERT INTO #TempData
	EXEC sp_executesql @Sql, N'@RowStart INT, @RowEnd INT', @RowStart, @RowEnd;

	DROP TABLE #AllData

	-- Get ticket detail
	IF EXISTS (SELECT 1 FROM #TempData WHERE WhTicket = 1)
	BEGIN
		-- Sportsbook
		IF EXISTS (SELECT 1 FROM @SportBettype WHERE ProductId = 1 AND EventType = 1 AND Bettype = @BetType)
		BEGIN
			INSERT INTO #Data
			SELECT
				td.RowNum,
				b.transid,
				b.refno,
				b.betid,
				b.custid,
				b.Username,
				m.sporttype,
				b.bettype,
				b.currency,
				m.leagueid,
				b.matchid,
				m.matchcode,
				m.GlobalShowTime AS EventDate,
				ISNULL(m.IsNeutral, CONVERT(BIT, 0)) AS IsNeutral,
				m.homeid,
				m.awayid,
				b.hdp1,
				b.hdp2,
				b.betteam,
				b.odds,
				b.oddstype,
				b.modds,
				b.liveindicator,
				b.livehomescore,
				b.liveawayscore,
				'' AS ShowTime,
				b.status,
				ISNULL(m.SettlementStatus, 0) AS SettlementStatus,
				m.betstatus,
				b.transdate,
				b.winlostdate,
				td.Stake,
				td.Actual_Stake,
				td.WinLost,
				td.LicenseeWL,
				td.Comm,
				td.PlayerComm,
				'' AS Race,
				ISNULL(b.betcheck, '') AS BetCheck,
				ISNULL(b.transdesc, '') AS TransDesc,
				ISNULL(b.betdaqid, -1) AS BetdaqId,
				ISNULL(b.ExtraInfo, '') AS ExtraInfo,
				CASE
					WHEN b.ExtraInfo LIKE '%p25%' THEN
						ISNULL(CAST(('<xml>' + b.ExtraInfo + '</xml>') AS XML).value('data(/xml/p25/@s)[1]','MONEY'), 0)
					ELSE 0
				END AS OriginalStake,
				CASE
					WHEN b.stake <> 0 THEN -1
					ELSE 0
				END AS OriginalBetType,
				td.WalletType,
				td.RefCode,
				ISNULL(b.oddsspread, 0) AS OddsSpread
			FROM dbo.bettrans AS b WITH (NOLOCK)
				INNER JOIN dbo.match AS m WITH (NOLOCK) ON b.matchid = m.matchid
				INNER JOIN #TempData AS td ON b.transid = td.TransId
			WHERE td.WhTicket = 1
				AND b.winlostdate BETWEEN @TempFromDate AND @ToDate
				AND b.bettype IN (SELECT bettype FROM @SportBettype)
				AND b.statusID NOT IN (0,1,101, 102, 103)
				AND b.matchid > 0 -- using index recommend-matchid-bettype
		END

		-- Outright
		IF EXISTS (SELECT 1 FROM @SportBettype WHERE ProductId = 1 AND EventType = 2 AND Bettype = @BetType)
		BEGIN
			INSERT INTO #Data
			SELECT
				td.RowNum,
				b.transid,
				b.refno,
				ISNULL(b.betid, 0) AS BetId,
				b.custid,
				b.Username,
				l.sporttype,
				b.bettype,
				b.currency,
				o.leagueid,
				b.matchid,
				o.matchcode,
				b.winlostdate AS EventDate,
				CONVERT(BIT, 0) AS IsNeutral,
				o.teamid AS HomeId,
				0 AS AwayId,
				0 AS Hdp1,
				0 AS Hdp2,
				'' AS BetTeam,
				b.odds,
				0 AS OddsType,
				b.modds,
				0 AS LiveIndicator,
				b.livehomescore,
				b.liveawayscore,
				'' AS ShowTime,
				b.status,
				0 AS SettlementStatus,
				'' AS BetStatus,
				b.transdate,
				b.winlostdate,
				b.stake,
				b.actual_stake,
				(b.winlost - b.actual_stake) AS WinLost,
				-(b.winlost - b.actual_stake) AS LicenseeWL,
				b.comm,
				b.playercomm,
				o.groupmatch AS Race,
				'' AS BetCheck,
				'' AS TransDesc,
				-1 AS BetdaqId,
				'' AS ExtraInfo,
				0 AS OriginalStake,
				0 AS OriginalBetType,
				0 AS WalletType,
				0 AS RefCode,
				0 AS OddsSpread
			FROM dbo.bettrans AS b WITH (NOLOCK)
				INNER JOIN dbo.outright AS o WITH (NOLOCK) ON b.matchid = o.orid
				INNER JOIN dbo.League AS l WITH (NOLOCK) ON o.leagueid = l.leagueid
				INNER JOIN #TempData AS td ON b.transid = td.TransId
			WHERE td.WhTicket = 1
				AND b.winlostdate BETWEEN @TempFromDate AND @ToDate
				AND b.bettype IN (SELECT bettype FROM @SportBettype)
				AND b.statusID NOT IN (0,1,101, 102, 103)
				AND b.matchid > 0 -- using index recommend-matchid-bettype
		END

		-- Mix Parlay, System Parlay (Sportsbook), Mix Parlay (Betradar Virtual Sports)
		IF EXISTS (SELECT 1 FROM @SportBettype WHERE ProductId IN (1, 27) AND EventType = 0 AND Bettype = @BetType)
		BEGIN
			INSERT INTO #Data
			SELECT
				td.RowNum,
				CASE
					WHEN b.bettype = 29 AND ISNULL(b.BetID, 0) > 0 THEN b.betid
					ELSE b.transid
				END AS TransId,
				b.refno,
				b.betid,
				b.custid,
				b.Username,
				0 AS SportType,
				b.bettype,
				b.currency,
				0 AS LeagueId,
				0 AS MatchId,
				'' AS MatchCode,
				b.winlostdate AS EventDate,
				CONVERT(BIT, 0) AS IsNeutral,
				0 AS HomeId,
				0 AS AwayId,
				b.hdp1,
				b.hdp2,
				b.betteam,
				b.odds,
				b.oddstype,
				b.modds,
				b.liveindicator,
				b.livehomescore,
				b.liveawayscore,
				'' AS ShowTime,
				b.status,
				0 AS SettlementStatus,
				'' AS BetStatus,
				b.transdate,
				b.winlostdate,
				b.stake,
				b.actual_stake,
				(b.winlost - b.actual_stake) AS WinLost,
				-(b.winlost - b.actual_stake) AS LicenseeWL,
				b.comm,
				b.playercomm,
				'' AS Race,
				ISNULL(b.betcheck, '') AS BetCheck,
				'' AS TransDesc,
				-1 AS BetdaqId,
				'' AS ExtraInfo,
				0 AS OriginalStake,
				0 AS OriginalBetType,
				0 AS WalletType,
				0 AS RefCode,
				0 AS OddsSpread
			FROM dbo.bettrans AS b WITH (NOLOCK)
				INNER JOIN #TempData AS td ON b.transid = td.TransId
			WHERE td.WhTicket = 1
				AND b.winlostdate BETWEEN @TempFromDate AND @ToDate
				AND b.bettype IN (SELECT bettype FROM @SportBettype)
				AND b.statusID NOT IN (0, 1, 101, 102, 103)
				AND b.matchid > 0 -- using index recommend-matchid-bettype
		END

		-- Number Game, Virtual Sports, Betradar Virtual Sports (EventType = 1)
		IF EXISTS (SELECT 1 FROM @SportBettype WHERE ProductId IN (3, 5, 27) AND EventType = 1 AND Bettype = @BetType)
		BEGIN
			INSERT INTO #Data
			SELECT
				td.RowNum,
				b.transid,
				b.refno,
				ISNULL(b.betid, 0) AS BetId,
				b.custid,
				b.Username,
				m.sporttype,
				b.bettype,
				b.currency,
				m.leagueid,
				m.matchid,
				m.matchcode,
				b.winlostdate AS EventDate,
				ISNULL(m.IsNeutral, CONVERT(BIT,0)) AS IsNeutral,
				m.homeid,
				m.awayid,
				CASE
					WHEN sbt.ProductId IN (3, 5, 27) THEN b.hdp1
					ELSE 0
				END AS Hdp1,
				CASE
					WHEN sbt.ProductId IN (5, 27) THEN b.hdp2
					ELSE 0
				END AS Hdp2,
				b.betteam,
				b.odds,
				b.oddstype,
				b.modds,
				b.liveindicator,
				b.livehomescore,
				b.liveawayscore,
				CASE
					WHEN sbt.ProductID IN (5, 27) THEN CONVERT(NVARCHAR(50), m.kickofftime)
					ELSE ISNULL(m.showtime,'')
				END AS ShowTime,
				b.status,
				0 AS SettlementStatus,
				m.betstatus,
				b.transdate,
				b.winlostdate,
				b.stake,
				b.actual_stake,
				(b.winlost - b.actual_stake) AS WinLost,
				-(b.winlost - b.actual_stake) AS LicenseeWL,
				b.comm,
				b.playercomm,
				'' AS Race,
				'' AS BetCheck,
				CASE
					WHEN sbt.ProductID = 27 THEN ISNULL(b.transdesc, '')
					ELSE ''
				END AS TransDesc,
				-1 AS BetdaqId,
				'' AS ExtraInfo,
				0 AS OriginalStake,
				0 AS OriginalBetType,
				0 AS WalletType,
				0 AS RefCode,
				0 AS OddsSpread
			FROM dbo.bettrans AS b WITH (NOLOCK)
				INNER JOIN dbo.match AS m WITH (NOLOCK) ON b.matchid = m.matchid
				INNER JOIN @SportBettype AS sbt ON b.bettype = sbt.Bettype
				INNER JOIN #TempData AS td ON b.transid = td.TransId
			WHERE td.WhTicket = 1
				AND b.winlostdate BETWEEN @TempFromDate AND @ToDate
				AND b.bettype IN (SELECT bettype FROM @SportBettype)
				AND b.statusID NOT IN (0, 1, 101, 102, 103)
				AND b.matchid > 0 -- using index recommend-matchid-bettype
		END

		-- Virtual Sports (EventType = 2)
		IF EXISTS (SELECT 1 FROM @SportBettype WHERE ProductId = 5 AND EventType = 3 AND Bettype = @BetType)
		BEGIN
			INSERT INTO #Data
			SELECT
				td.RowNum,
				b.transid,
				b.refno,
				ISNULL(b.betid, 0) AS BetId,
				b.custid,
				b.Username,
				r.sporttype,
				b.bettype,
				b.currency,
				r.LeagueID,
				b.matchid,
				CONVERT(VARCHAR(50), o.RacerNum) AS MatchCode,
				b.winlostdate AS EventDate,
				CONVERT(BIT, 0) AS IsNeutral,
				o.RacerID AS HomeId,
				0 AS AwayId,
				b.hdp1,
				b.hdp2,
				'' AS BetTeam,
				b.odds,
				0 AS OddsType,
				b.modds,
				0 AS LiveIndicator,
				b.livehomescore,
				b.liveawayscore,
				CONVERT(NVARCHAR(50), r.EventTime) AS ShowTime,
				b.status,
				0 AS SettlementStatus,
				'' AS BetStatus,
				b.transdate,
				b.winlostdate,
				b.stake,
				b.actual_stake,
				(b.winlost - b.actual_stake) AS WinLost,
				-(b.winlost - b.actual_stake) AS LicenseeWL,
				b.comm,
				b.playercomm,
				CONVERT(VARCHAR(20), b.oddsid) AS Race,
				'' AS BetCheck,
				'' AS TransDesc,
				-1 AS BetdaqId,
				'' AS ExtraInfo,
				0 AS OriginalStake,
				0 AS OriginalBetType,
				0 AS WalletType,
				0 AS RefCode,
				0 AS OddsSpread
			FROM dbo.bettrans AS b WITH (NOLOCK)
				INNER JOIN dbo.VSOutright AS o WITH (NOLOCK) ON b.oddsid = o.orid
				INNER JOIN dbo.VSRaceInfo AS r WITH (NOLOCK) ON r.EventID = o.EventID
				INNER JOIN #TempData AS td ON b.transid = td.TransId
			WHERE td.WhTicket = 1
				AND b.winlostdate BETWEEN @TempFromDate AND @ToDate
				AND b.bettype IN (SELECT bettype FROM @SportBettype)
				AND b.statusID NOT IN (0,1,101, 102, 103)
				AND b.matchid > 0 -- using index recommend-matchid-bettype
		END

		-- Keno, Lottery, Table Games, Indo 4D
		IF EXISTS (SELECT 1 FROM @SportBettype WHERE ProductId IN (8, 28, 40, 43) AND Bettype = @BetType)
		BEGIN
			INSERT INTO #Data
			SELECT
				td.RowNum,
				b.transid,
				b.refno,
				ISNULL(b.betid, 0) AS BetId,
				b.custid,
				b.Username,
				CASE
					WHEN sbt.ProductId = 8 THEN 202
					WHEN sbt.ProductId = 28 THEN 220
					WHEN sbt.ProductId IN (40, 43) THEN b.matchid
					ELSE 0
				END AS SportType,
				b.bettype,
				b.currency,
				0 AS LeagueId,
				0 AS MatchId,
				'' AS MatchCode,
				b.winlostdate AS EventDate,
				CONVERT(BIT, 0) AS IsNeutral,
				0 AS HomeId,
				0 AS AwayId,
				0 AS Hdp1,
				0 AS Hdp2,
				'' AS BetTeam,
				b.odds,
				b.oddstype,
				0 AS Modds,
				0 AS LiveIndicator,
				0 AS LiveHomeScore,
				0 AS LiveAwayScore,
				'' AS ShowTime,
				b.status,
				0 AS SettlementStatus,
				'' AS BetStatus,
				b.transdate,
				b.winlostdate,
				b.stake,
				b.actual_stake,
				(b.winlost - b.actual_stake) AS WinLost,
				-(b.winlost - b.actual_stake) AS LicenseeWL,
				b.comm,
				b.playercomm,
				'' AS Race,
				CASE
					WHEN sbt.ProductId = 8 THEN ISNULL(b.comstatus, '')
					ELSE ''
				END AS BetCheck,
				ISNULL(b.transdesc, '') AS TransDesc,
				-1 AS BetdaqId,
				'' AS ExtraInfo,
				0 AS OriginalStake,
				0 AS OriginalBetType,
				0 AS WalletType,
				0 AS RefCode,
				0 AS OddsSpread
			FROM dbo.bettrans AS b WITH (NOLOCK)
				INNER JOIN #TempData AS td ON b.transid = td.TransId
				INNER JOIN @SportBettype AS sbt ON b.bettype = sbt.Bettype
			WHERE td.WhTicket = 1
				AND b.winlostdate BETWEEN @TempFromDate AND @ToDate
				AND b.statusID NOT IN (0, 1, 101, 102, 103)
				AND b.matchid > 0 -- using index recommend-matchid-bettype
		END
	END

	IF EXISTS (SELECT 1 FROM #TempData WHERE WhTicket = 2)
	BEGIN
		-- Sportsbook
		IF EXISTS (SELECT 1 FROM @SportBettype WHERE ProductId = 1 AND EventType = 1 AND Bettype = @BetType)
		BEGIN
			INSERT INTO #Data
			SELECT
				td.RowNum,
				b.transid,
				b.refno,
				b.betid,
				b.custid,
				b.Username,
				m.sporttype,
				b.bettype,
				b.currency,
				m.leagueid,
				b.matchid,
				m.matchcode,
				m.GlobalShowTime AS EventDate,
				ISNULL(m.isNeutral, CONVERT(BIT, 0)) AS IsNeutral,
				m.homeid,
				m.awayid,
				b.hdp1,
				b.hdp2,
				b.betteam,
				b.odds,
				b.oddstype,
				b.modds,
				b.liveindicator,
				b.livehomescore,
				b.liveawayscore,
				'' AS ShowTime,
				b.status,
				0 AS SettlementStatus,
				m.betstatus,
				b.transdate,
				b.winlostdate,
				td.Stake,
				td.Actual_Stake,
				td.WinLost,
				td.LicenseeWL,
				td.Comm,
				td.PlayerComm,
				'' AS Race,
				ISNULL(b.betcheck, '') AS BetCheck,
				ISNULL(b.transdesc, '') AS TransDesc,
				ISNULL(b.betdaqid, -1) AS BetdaqId,
				ISNULL(b.ExtraInfo, '') AS ExtraInfo,
				CASE
					WHEN b.ExtraInfo LIKE '%p25%' THEN
						ISNULL(CAST(('<xml>' + b.ExtraInfo + '</xml>') AS XML).value('data(/xml/p25/@s)[1]','MONEY'), 0)
					ELSE 0
				END AS OriginalStake,
				CASE
					WHEN b.stake <> 0 THEN -1
					ELSE 0
				END AS OriginalBetType,
				td.WalletType,
				td.RefCode,
				ISNULL(b.oddsspread, 0) AS OddsSpread
			FROM dbo.bettrans14 AS b WITH (NOLOCK)
				INNER JOIN dbo.match14 AS m WITH (NOLOCK) ON b.matchid = m.matchid
				INNER JOIN #TempData AS td ON b.transid = td.TransId
			WHERE td.WhTicket = 2
				AND b.winlostdate BETWEEN @BalanceUpDay AND @TempToDate
				AND b.bettype IN (SELECT bettype FROM @SportBettype)
				AND b.statusID NOT IN (101, 102, 103)
				AND b.matchid > 0 -- using index recommend-winlostdate-bettype-matchid-statusID
		END

		-- Outright
		IF EXISTS (SELECT 1 FROM @SportBettype WHERE ProductId = 1 AND EventType = 2 AND Bettype = @BetType)
		BEGIN
			INSERT INTO #Data
			SELECT
				td.RowNum,
				b.transid,
				b.refno,
				ISNULL(b.betid, 0) AS BetId,
				b.custid,
				b.Username,
				l.sporttype,
				b.bettype,
				b.currency,
				o.leagueid,
				b.matchid,
				o.matchcode,
				b.winlostdate AS EventDate,
				CONVERT(BIT, 0) AS IsNeutral,
				o.teamid AS HomeId,
				0 AS AwayId,
				0 AS Hdp1,
				0 AS Hdp2,
				'' AS BetTeam,
				b.odds,
				0 AS OddsType,
				b.modds,
				0 AS LiveIndicator,
				b.livehomescore,
				b.liveawayscore,
				'' AS ShowTime,
				b.status,
				0 AS SettlementStatus,
				'' AS BetStatus,
				b.transdate,
				b.winlostdate,
				b.stake,
				b.actual_stake,
				(b.winlost - b.actual_stake) AS WinLost,
				-(b.winlost - b.actual_stake) AS LicenseeWL,
				b.comm,
				b.playercomm,
				o.groupmatch AS Race,
				'' AS BetCheck,
				'' AS TransDesc,
				-1 AS BetdaqId,
				'' AS ExtraInfo,
				0 AS OriginalStake,
				0 AS OriginalBetType,
				0 AS WalletType,
				0 AS RefCode,
				0 AS OddsSpread
			FROM dbo.bettrans14 AS b WITH (NOLOCK)
				INNER JOIN dbo.outright14 AS o WITH (NOLOCK) ON b.matchid = o.orid
				INNER JOIN dbo.League AS l WITH (NOLOCK) ON o.leagueid = l.leagueid
				INNER JOIN #TempData AS td ON b.transid = td.TransId
			WHERE td.WhTicket = 2
				AND b.winlostdate BETWEEN @BalanceUpDay AND @TempToDate
				AND b.bettype IN (SELECT bettype FROM @SportBettype)
				AND b.statusID NOT IN (101, 102, 103)
				AND b.matchid > 0 -- using index recommend-winlostdate-bettype-matchid-statusID
		END

		-- Mix Parlay, System Parlay (Sportsbook), Mix Parlay (Betradar Virtual Sports)
		IF EXISTS (SELECT 1 FROM @SportBettype WHERE ProductId IN (1, 27) AND EventType = 0 AND Bettype = @BetType)
		BEGIN
			INSERT INTO #Data
			SELECT
				td.RowNum,
				CASE
					WHEN b.bettype = 29 AND ISNULL(b.betid, 0) > 0 THEN b.betid
					ELSE b.transid
				END AS TransId,
				b.refno,
				b.betid,
				b.custid,
				b.Username,
				0 AS SportType,
				b.bettype,
				b.currency,
				0 AS LeagueId,
				0 AS MatchId,
				'' AS MatchCode,
				b.winlostdate AS EventDate,
				CONVERT(BIT, 0) AS IsNeutral,
				0 AS HomeId,
				0 AS AwayId,
				b.hdp1,
				b.hdp2,
				b.betteam,
				b.odds,
				b.oddstype,
				b.modds,
				b.liveindicator,
				b.livehomescore,
				b.liveawayscore,
				'' AS ShowTime,
				b.status,
				0 AS SettlementStatus,
				'' AS BetStatus,
				b.transdate,
				b.winlostdate,
				b.stake,
				b.actual_stake,
				(b.winlost - b.actual_stake) AS WinLost,
				-(b.winlost - b.actual_stake) AS LicenseeWL,
				b.comm,
				b.playercomm,
				'' AS Race,
				ISNULL(b.betcheck, '') AS BetCheck,
				'' AS TransDesc,
				-1 AS BetdaqId,
				'' AS ExtraInfo,
				0 AS OriginalStake,
				0 AS OriginalBetType,
				0 AS WalletType,
				0 AS RefCode,
				0 AS OddsSpread
			FROM dbo.bettrans14 AS b WITH (NOLOCK)
				INNER JOIN #TempData AS td ON b.transid = td.TransId
			WHERE td.WhTicket = 2
				AND b.winlostdate BETWEEN @BalanceUpDay AND @TempToDate
				AND b.bettype IN (SELECT bettype FROM @SportBettype)
				AND b.statusID NOT IN (101, 102, 103)
				AND b.matchid > 0 -- using index recommend-winlostdate-bettype-matchid-statusID
		END

		-- Number Game, Virtual Sports, Betradar Virtual Sports (EventType = 1)
		IF EXISTS (SELECT 1 FROM @SportBettype WHERE ProductId IN (3, 5, 27) AND EventType = 1 AND Bettype = @BetType)
		BEGIN
			INSERT INTO #Data
			SELECT
				td.RowNum,
				b.transid,
				b.refno,
				ISNULL(b.BetID, 0) AS BetId,
				b.custid,
				b.Username,
				m.sporttype,
				b.bettype,
				b.currency,
				m.leagueid,
				m.matchid,
				m.matchcode,
				b.winlostdate AS EventDate,
				ISNULL(m.IsNeutral, CONVERT(BIT,0)) AS IsNeutral,
				m.homeid,
				m.awayid,
				CASE
					WHEN sbt.ProductId IN (3, 5, 27) THEN b.hdp1
					ELSE 0
				END AS Hdp1,
				CASE
					WHEN sbt.ProductId IN (5, 27) THEN b.hdp2
					ELSE 0
				END AS Hdp2,
				b.betteam,
				b.odds,
				b.oddstype,
				b.modds,
				b.liveindicator,
				b.livehomescore,
				b.liveawayscore,
				CASE
					WHEN sbt.ProductID IN (5, 27) THEN CONVERT(NVARCHAR(50), m.kickofftime)
					ELSE ISNULL(m.showtime,'')
				END AS ShowTime,
				b.status,
				0 AS SettlementStatus,
				m.betstatus,
				b.transdate,
				b.winlostdate,
				b.stake,
				b.actual_stake,
				(b.winlost - b.actual_stake) AS WinLost,
				-(b.winlost - b.actual_stake) AS LicenseeWL,
				b.comm,
				b.playercomm,
				'' AS Race,
				'' AS BetCheck,
				CASE
					WHEN sbt.ProductID = 27 THEN ISNULL(b.transdesc, '')
					ELSE ''
				END AS TransDesc,
				-1 AS BetdaqId,
				'' AS ExtraInfo,
				0 AS OriginalStake,
				0 AS OriginalBetType,
				0 AS WalletType,
				0 AS RefCode,
				0 AS OddsSpread
			FROM dbo.bettrans14 AS b WITH (NOLOCK)
				INNER JOIN dbo.match14 AS m WITH (NOLOCK) ON b.matchid = m.matchid
				INNER JOIN @SportBettype AS sbt ON b.bettype = sbt.Bettype
				INNER JOIN #TempData AS td ON b.transid = td.TransId
			WHERE td.WhTicket = 2
				AND b.winlostdate BETWEEN @BalanceUpDay AND @TempToDate
				AND b.bettype IN (SELECT bettype FROM @SportBettype)
				AND b.statusID NOT IN (101, 102, 103)
				AND b.matchid > 0 -- using index recommend-winlostdate-bettype-matchid-statusID
		END

		-- Virtual Sports (EventType = 2)
		IF EXISTS (SELECT 1 FROM @SportBettype WHERE ProductId = 5 AND EventType = 3 AND Bettype = @BetType)
		BEGIN
			INSERT INTO #Data
			SELECT
				td.RowNum,
				b.transid,
				b.refno,
				ISNULL(b.betid, 0) AS BetId,
				b.custid,
				b.Username,
				r.sporttype,
				b.bettype,
				b.currency,
				r.LeagueID,
				b.matchid,
				CONVERT(VARCHAR(50), o.RacerNum) AS MatchCode,
				b.winlostdate AS EventDate,
				CONVERT(BIT, 0) AS IsNeutral,
				o.RacerID AS HomeId,
				0 AS AwayId,
				b.hdp1,
				b.hdp2,
				'' AS BetTeam,
				b.odds,
				0 AS OddsType,
				b.modds,
				0 AS LiveIndicator,
				b.livehomescore,
				b.liveawayscore,
				CONVERT(NVARCHAR(50), r.EventTime) AS ShowTime,
				b.status,
				0 AS SettlementStatus,
				'' AS BetStatus,
				b.transdate,
				b.winlostdate,
				b.stake,
				b.actual_stake,
				(b.winlost - b.actual_stake) AS WinLost,
				-(b.winlost - b.actual_stake) AS LicenseeWL,
				b.comm,
				b.playercomm,
				CONVERT(VARCHAR(20), b.oddsid) AS Race,
				'' AS BetCheck,
				'' AS TransDesc,
				-1 AS BetdaqId,
				'' AS ExtraInfo,
				0 AS OriginalStake,
				0 AS OriginalBetType,
				0 AS WalletType,
				0 AS RefCode,
				0 AS OddsSpread
			FROM dbo.bettrans14 AS b WITH (NOLOCK)
				INNER JOIN dbo.VSOutright14 AS o WITH (NOLOCK) ON b.oddsid = o.orid
				INNER JOIN dbo.VSRaceInfo AS r WITH (NOLOCK) ON r.EventID = o.EventID
				INNER JOIN #TempData AS td ON b.transid = td.TransId
			WHERE td.WhTicket = 2
				AND b.winlostdate BETWEEN @BalanceUpDay AND @TempToDate
				AND b.bettype IN (SELECT bettype FROM @SportBettype)
				AND b.statusID NOT IN (101, 102, 103)
				AND b.matchid > 0 -- using index recommend-winlostdate-bettype-matchid-statusID
		END

		-- Keno, Lottery, Table Games, Indo 4D
		IF EXISTS (SELECT 1 FROM @SportBettype WHERE ProductId IN (8, 28, 40, 43) AND Bettype = @BetType)
		BEGIN
			INSERT INTO #Data
			SELECT
				td.RowNum,
				b.transid,
				b.refno,
				ISNULL(b.betid, 0) AS BetId,
				b.custid,
				b.Username,
				CASE
					WHEN sbt.ProductId = 8 THEN 202
					WHEN sbt.ProductId = 28 THEN 220
					WHEN sbt.ProductId IN (40, 43) THEN b.matchid
					ELSE 0
				END AS SportType,
				b.bettype,
				b.currency,
				0 AS LeagueId,
				0 AS MatchId,
				'' AS MatchCode,
				b.winlostdate AS EventDate,
				CONVERT(BIT, 0) AS IsNeutral,
				0 AS HomeId,
				0 AS AwayId,
				0 AS Hdp1,
				0 AS Hdp2,
				'' AS BetTeam,
				b.odds,
				b.oddstype,
				0 AS Modds,
				0 AS LiveIndicator,
				0 AS LiveHomeScore,
				0 AS LiveAwayScore,
				'' AS ShowTime,
				b.status,
				0 AS SettlementStatus,
				'' AS BetStatus,
				b.transdate,
				b.winlostdate,
				b.stake,
				b.actual_stake,
				(b.winlost - b.actual_stake) AS WinLost,
				-(b.winlost - b.actual_stake) AS LicenseeWL,
				b.comm,
				b.playercomm,
				'' AS Race,
				CASE
					WHEN sbt.ProductId = 8 THEN ISNULL(b.comstatus, '')
					ELSE ''
				END AS BetCheck,
				ISNULL(b.transdesc, '') AS TransDesc,
				-1 AS BetdaqId,
				'' AS ExtraInfo,
				0 AS OriginalStake,
				0 AS OriginalBetType,
				0 AS WalletType,
				0 AS RefCode,
				0 AS OddsSpread
			FROM dbo.bettrans14 AS b WITH (NOLOCK)
				INNER JOIN #TempData AS td ON b.transid = td.TransId
				INNER JOIN @SportBettype AS sbt ON b.bettype = sbt.Bettype
			WHERE td.WhTicket = 2
				AND b.winlostdate BETWEEN @BalanceUpDay AND @TempToDate
				AND b.statusID NOT IN (101, 102, 103)
				AND b.matchid > 0 -- using index recommend-winlostdate-bettype-matchid-statusID
		END
	END

	SELECT
		b.RowNum,
		b.TransId,
		b.RefNo,
		b.BetId,
		b.CustId,
		b.Username,
		SUBSTRING(c.username2, CHARINDEX('$', c.username2) + 1, LEN(c.username2) - CHARINDEX('$', c.username2)) AS Nickname,
		b.SportType,
		b.BetType,
		b.Currency,
		b.LeagueId,
		b.MatchId,
		b.MatchCode,
		b.EventDate,
		b.IsNeutral,
		b.HomeId,
		b.AwayId,
		b.Hdp1,
		b.Hdp2,
		b.BetTeam,
		b.Odds,
		b.OddsType,
		b.Modds,
		b.LiveIndicator,
		b.LiveHomeScore,
		b.LiveAwayScore,
		b.ShowTime,
		b.Status,
		b.SettlementStatus,
		b.BetStatus,
		b.TransDate,
		b.WinLostDate,
		b.Stake * ISNULL(e.Rate, 1) AS Stake,
		b.Actual_Stake,
		b.WinLost * ISNULL(e.Rate, 1) AS WinLost,
		b.LicenseeWL * ISNULL(e.Rate, 1) AS LicenseeWL,
		b.Comm * ISNULL(e.Rate, 1) AS Comm,
		b.PlayerComm * ISNULL(e.Rate, 1) AS PlayerComm,
		b.Race,
		b.BetCheck,
		b.TransDesc,
		b.BetdaqId,
		b.ExtraInfo,
		b.OriginalStake,
		b.OriginalBetType,
		b.WalletType,
		b.RefCode,
		b.OddsSpread
	FROM #Data AS b
		INNER JOIN dbo.Customer AS c (NOLOCK) ON b.custid = c.custid
		LEFT JOIN #ExchangeRate AS e
			ON e.ExchangeId = b.Currency
				AND b.WinLostDate BETWEEN e.FirstExchangeDateByMonth AND e.LastExchangeDateByMonth
	ORDER BY b.RowNum ASC

	-- Get sub tickets
	DECLARE @BettransDetail TABLE (
		RefNo			BIGINT,
		Odds			MONEY,
		Stake			MONEY,
		Status			NVARCHAR(10),
		APositionTaking	SMALLMONEY,
		BetType			SMALLINT,
		BetTeam			NVARCHAR(10)
	)

	-- Virtual Sports
	IF EXISTS (	SELECT 1
				FROM #Data AS b
					INNER JOIN @SportBettype AS sbt ON b.bettype = sbt.Bettype
				WHERE sbt.ProductId = 5 AND sbt.EventType = 3)
	BEGIN
		INSERT INTO @BettransDetail
		SELECT
			bm.refno,
			bm.odds,
			bm.stake * ISNULL(e.Rate, 1) AS Stake,
			bm.status,
			bm.apositiontaking,
			bm.bettype,
			bm.betteam
		FROM dbo.bettransm AS bm WITH (NOLOCK)
			INNER JOIN #Data AS b ON bm.refno = b.RefNo AND bm.custid = b.custid
			INNER JOIN @SportBettype AS sbt ON b.bettype = sbt.Bettype
			INNER JOIN @SportBettype AS sbtm ON bm.bettype = sbtm.Bettype
			LEFT JOIN #ExchangeRate AS e
				ON e.ExchangeId = b.Currency
					AND b.WinLostDate BETWEEN e.FirstExchangeDateByMonth AND e.LastExchangeDateByMonth
		WHERE sbt.ProductId = 5
			AND sbt.EventType = 3
			AND sbtm.ProductId = 5
			AND sbtm.EventType = 3

		INSERT INTO @BettransDetail
		SELECT
			bm.refno,
			bm.odds,
			bm.stake * ISNULL(e.Rate, 1) AS Stake,
			bm.status,
			bm.apositiontaking,
			bm.bettype,
			bm.betteam
		FROM dbo.bettransm14 AS bm WITH (NOLOCK)
			INNER JOIN #Data AS b ON bm.refno = b.RefNo AND bm.custid = b.custid
			INNER JOIN @SportBettype AS sbt ON b.bettype = sbt.Bettype
			INNER JOIN @SportBettype AS sbtm ON bm.bettype = sbtm.Bettype
			LEFT JOIN #ExchangeRate AS e
				ON e.ExchangeId = b.Currency
					AND b.WinLostDate BETWEEN e.FirstExchangeDateByMonth AND e.LastExchangeDateByMonth
		WHERE sbt.ProductId = 5
			AND sbt.EventType = 3
			AND sbtm.ProductId = 5
			AND sbtm.EventType = 3
	END

	SELECT DISTINCT * FROM @BettransDetail
	ORDER BY RefNo ASC, BetType ASC

	DROP TABLE #ExchangeRate
	DROP TABLE #Data
	DROP TABLE #TempData
END
GO




GRANT	EXECUTE	ON	Lrf_BetList_SelWinLossByBetType	TO	bodbLicenseeNet
GO
