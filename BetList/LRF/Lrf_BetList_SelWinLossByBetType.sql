USE [bodb02]
GO

ALTER PROCEDURE [dbo].[Lrf_BetList_SelWinLossByBetType]
	@AgentList			VARCHAR(MAX),
	@BetType			INT,
	@FromDate			SMALLDATETIME,
	@ToDate				SMALLDATETIME,
	@MoveBetsDay		SMALLDATETIME,
	@BalanceUpDay		SMALLDATETIME,
	@PageSize			INT				= 1000,
	@PageIndex			INT				= 1,
	@Sort				VARCHAR(100)	= 'TransId ASC',
	@TotalRows			INT				= 0 OUTPUT,
	@SumWinLost			MONEY			= 0 OUTPUT,
	@SumWinLostUSD		MONEY			= 0 OUTPUT,
	@SumWinLostEUR		MONEY			= 0 OUTPUT,
	@SumWinLostGBP		MONEY			= 0 OUTPUT,
	@SumLicenseeWL		MONEY			= 0 OUTPUT,
	@SumLicenseeWLUSD	MONEY			= 0 OUTPUT,
	@SumLicenseeWLEUR	MONEY			= 0 OUTPUT,
	@SumLicenseeWLGBP	MONEY			= 0 OUTPUT,
	@SumComm			MONEY			= 0 OUTPUT,
	@SumCommUSD			MONEY			= 0 OUTPUT,
	@SumCommEUR			MONEY			= 0 OUTPUT,
	@SumCommGBP			MONEY			= 0 OUTPUT,
	@SumPlayerComm		MONEY			= 0 OUTPUT,
	@SumPlayerCommUSD	MONEY			= 0 OUTPUT,
	@SumPlayerCommEUR	MONEY			= 0 OUTPUT,
	@SumPlayerCommGBP	MONEY			= 0 OUTPUT
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

	Parameters:
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
			ErrMsg = N'Paramter invalid.'

		RETURN
	END CATCH

	-- Sport Bet Type matrix
	DECLARE @SportBettype TABLE(ProductId TINYINT, Bettype SMALLINT, EventType TINYINT)

	DECLARE @isTest BIT
	SELECT @isTest = dbo.f_CheckSPVersion(@@PROCID)

	INSERT INTO @SportBettype
	SELECT DISTINCT ProductId, Bettype, EventType
	FROM dbo.f_SportBettypeMatrix_Sel(0, 0, 0, 2, '', '', @isTest)
	WHERE
		ProductID IN (1, 2, 3, 5, 8, 27, 28)
		AND Bettype NOT IN (901, 902, 903, 904, 911, 912, 913, 914)
		AND bettype IN (
			SELECT bettype FROM dbo.f_GroupBettype() WHERE GroupTypeId = @BetType
			UNION SELECT GroupTypeId FROM dbo.f_GroupBettype() WHERE bettype = @BetType
			UNION SELECT @BetType)
	/*
	DELETE FROM @SportBettype
	WHERE ProductID NOT IN (1, 2, 3, 4, 5, 8)
		OR (ProductID = 1 AND Bettype IN (901, 902, 903, 904))
	*/

	-- Create temp table
	CREATE TABLE #AllData (
		TransId			BIGINT,
		RefNo			BIGINT,
		Currency		SMALLINT,
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
		RowNum			INT,
		TransId			BIGINT,
		RefNo			BIGINT,
		BetId			BIGINT,
		CustId			INT,
		Username		NVARCHAR(50),
		SportType		INT,
		BetType			INT,
		Currency		SMALLINT,
		LeagueId		INT,
		MatchId			INT,
		MatchCode		VARCHAR(50),
		IsNeutral		BIT,
		HomeId			INT,
		AwayId			INT,
		Hdp1			SMALLMONEY,
		Hdp2			SMALLMONEY,
		BetTeam			NVARCHAR(10),
		Odds			MONEY,
		OddsType		TINYINT,
		Modds			MONEY,
		LiveIndicator	BIT,
		LiveHomeScore	SMALLINT,
		LiveAwayScore	SMALLINT,
		ShowTime		NVARCHAR(50),
		Status			NVARCHAR(10),
		BetStatus		NVARCHAR(50),
		TransDate		DATETIME,
		WinLostDate		DATETIME,
		Stake			MONEY,
		Actual_Stake	MONEY,
		WinLost			MONEY,
		LicenseeWL		MONEY,
		Comm			MONEY,
		PlayerComm		MONEY,
		Race			VARCHAR(20),
		BetCheck		NVARCHAR(50),
		TransDesc		NVARCHAR(1000),
		BetdaqId		BIGINT,
		ExtraInfo		VARCHAR(1000),
		OriginalStake	MONEY,
		OriginalBetType	SMALLINT,
		WalletType		TINYINT,
		RefCode			BIGINT,
		OddsSpread		MONEY
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
			INSERT INTO #AllData
			SELECT
				b.transid,
				b.refno,
				b.currency,
				b.winlostdate,
				b.stake,
				b.actual_stake,
				(b.winlost - b.actual_stake) AS WinLost,
				-(b.winlost - b.actual_stake) AS LicenseeWL,
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
				INNER JOIN @TempAg AS t ON b.recommend = t.CustId AND b.currency = t.currency
				INNER JOIN @SportBettype AS s ON b.bettype = s.Bettype
				LEFT JOIN dbo.f_GroupBettype() AS ss ON b.bettype = ss.bettype
			WHERE
				b.winlostdate BETWEEN @TempFromDate AND @ToDate
				AND CASE WHEN ss.Bettype IS NULL THEN b.bettype ELSE ss.Grouptypeid END = @BetType
				AND b.statusID NOT IN (0, 1, 101, 102, 103)
				AND b.matchid > 0 -- using index recommend-matchid-bettype
		ELSE
			INSERT INTO #AllData
			SELECT
				b.transid,
				b.refno,
				b.currency,
				b.winlostdate,
				b.stake,
				b.actual_stake,
				(b.winlost - b.actual_stake) AS WinLost,
				-(b.winlost - b.actual_stake) AS LicenseeWL,
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
				INNER JOIN @TempAg AS t ON b.recommend = t.CustId AND b.currency = t.currency
				INNER JOIN @SportBettype AS s ON b.bettype = s.Bettype
			WHERE
				b.winlostdate BETWEEN @TempFromDate AND @ToDate
				AND b.bettype = @BetType
				AND b.statusID NOT IN (0, 1, 101, 102, 103)
				AND b.matchid > 0 -- using index recommend-matchid-bettype
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
			INSERT INTO #AllData
			SELECT
				b.transid,
				b.refno,
				b.currency,
				b.winlostdate,
				b.stake,
				b.actual_stake,
				(b.winlost - b.actual_stake) AS WinLost,
				-(b.winlost - b.actual_stake) AS LicenseeWL,
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
				INNER JOIN @TempAg AS t ON b.recommend = t.CustId AND b.currency = t.currency
				INNER JOIN @SportBettype AS s ON b.bettype = s.Bettype
				LEFT JOIN dbo.f_GroupBettype() AS ss ON b.bettype = ss.bettype
			WHERE
				b.winlostdate BETWEEN @BalanceUpDay AND @TempToDate
				AND CASE WHEN ss.Bettype IS NULL THEN b.bettype ELSE ss.Grouptypeid END = @BetType
				AND b.statusID NOT IN (101, 102, 103)
				AND b.matchid > 0 -- using index recommend-winlostdate-bettype-matchid-statusID
		ELSE
			INSERT INTO #AllData
			SELECT
				b.transid,
				b.refno,
				b.currency,
				b.winlostdate,
				b.stake,
				b.actual_stake,
				(b.winlost - b.actual_stake) AS WinLost,
				-(b.winlost - b.actual_stake) AS LicenseeWL,
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
				INNER JOIN @TempAg AS t ON b.recommend = t.CustId AND b.currency = t.currency
				INNER JOIN @SportBettype AS s ON b.bettype = s.Bettype
			WHERE
				b.winlostdate BETWEEN @BalanceUpDay AND @TempToDate
				AND b.bettype = @BetType
				AND b.statusID NOT IN (101, 102, 103)
				AND b.matchid > 0 -- using index recommend-winlostdate-bettype-matchid-statusID
	END

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

	DECLARE @RowStart	INT,
		@RowEnd			INT

	SELECT @PageIndex = @PageIndex - 1,
		@RowStart = @PageSize * @PageIndex + 1,
		@RowEnd = @RowStart + @PageSize - 1

	-- Get exchange rate
	SELECT * 
	INTO #TempExchange
	FROM Lrf_f_GetExchangeDaily(@FromDate, @ToDate)
	-- WHERE ExchangeId IN (SELECT DISTINCT CurrencyId FROM #Currency) (no need)

	-- Get total values
	SELECT
		@TotalRows			= COUNT(b.TransId),
		@SumWinlost			= SUM(ISNULL(b.WinLost, 0)),
		@SumLicenseeWL		= SUM(ISNULL(b.LicenseeWL, 0)),
		@SumComm			= SUM(ISNULL(b.Comm, 0)),
		@SumPlayerComm		= SUM(ISNULL(b.PlayerComm, 0)),
		-- USD
		@SumWinlostUSD		= SUM(ISNULL(b.WinLost		* e.USD, 0)),
		@SumLicenseeWLUSD	= SUM(ISNULL(b.LicenseeWL	* e.USD, 0)),
		@SumCommUSD			= SUM(ISNULL(b.Comm			* e.USD, 0)),
		@SumPlayerCommUSD	= SUM(ISNULL(b.PlayerComm	* e.USD, 0)),
		-- EUR
		@SumWinlostEUR		= SUM(ISNULL(b.WinLost		* e.EUR, 0)),
		@SumLicenseeWLEUR	= SUM(ISNULL(b.LicenseeWL	* e.EUR, 0)),
		@SumCommEUR			= SUM(ISNULL(b.Comm			* e.EUR, 0)),
		@SumPlayerCommEUR	= SUM(ISNULL(b.PlayerComm	* e.EUR, 0)),
		-- GBP
		@SumWinlostGBP		= SUM(ISNULL(b.WinLost		* e.GBP, 0)),
		@SumLicenseeWLGBP	= SUM(ISNULL(b.LicenseeWL	* e.GBP, 0)),
		@SumCommGBP			= SUM(ISNULL(b.Comm			* e.GBP, 0)),
		@SumPlayerCommGBP	= SUM(ISNULL(b.PlayerComm	* e.GBP, 0))
	FROM #AllData AS b
		INNER JOIN #TempExchange AS e ON e.ExchangeDate = b.WinLostDate AND e.Exchangeid = b.Currency

	-- Exchange rate is different for each day => Stake order may be different from StakeUSD order
	DECLARE @SortExp VARCHAR(200)

	IF @Sort LIKE '%USD%' OR @Sort LIKE '%EUR%' OR @Sort LIKE '%GBP%'
	BEGIN
		DECLARE @CharIndex INT

		SELECT @CharIndex = CHARINDEX( ' ', @Sort, 1)
		SELECT @SortExp = SUBSTRING (@Sort, 1, @CharIndex - 4) + ' * e.' 
			+ SUBSTRING(@Sort, @CharIndex - 3, 4) + SUBSTRING(@Sort, @CharIndex + 1, LEN(@Sort))
	END
	ELSE
	BEGIN
		SET @SortExp = @Sort
	END

	IF @SortExp NOT LIKE '%TransId%'
	BEGIN
		SELECT @SortExp = @SortExp + ', TransId ASC'
	END

	DECLARE @Sql NVARCHAR(1000)

	SET @Sql = 
		'INSERT INTO #TempData
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
				ROW_NUMBER() OVER (ORDER BY ' + @SortExp + ') AS RowNum,
				b.* 
			FROM #AllData AS b
				INNER JOIN #TempExchange AS e ON e.exchangeid = b.Currency AND e.ExchangeDate = b.WinLostDate
		) AS tmp
		WHERE tmp.RowNum BETWEEN ' + CAST(@RowStart AS VARCHAR(50)) + ' AND ' + CAST(@RowEnd AS VARCHAR(50))
		+ ' ORDER BY tmp.RowNum'

	EXEC sp_executesql @sql

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

		-- Horse Racing (EventType = 2)
		IF EXISTS (SELECT 1 FROM @SportBettype WHERE ProductId = 2 AND Bettype = @BetType)
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

		-- Keno, Lottery
		IF EXISTS (SELECT 1 FROM @SportBettype WHERE ProductId IN (8, 28) AND Bettype = @BetType)
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
					ELSE 0
				END AS SportType,
				b.bettype,
				b.currency,
				0 AS LeagueId,
				0 AS MatchId,
				'' AS MatchCode,
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
				'' AS BetCheck,
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

		-- Horse Racing (EventType = 2)
		IF EXISTS (SELECT 1 FROM @SportBettype WHERE ProductId = 2 AND Bettype = @BetType)
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

		-- Keno, Lottery
		IF EXISTS (SELECT 1 FROM @SportBettype WHERE ProductId IN (8, 28) AND Bettype = @BetType)
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
					ELSE 0
				END AS SportType,
				b.bettype,
				b.currency,
				0 AS LeagueId,
				0 AS MatchId,
				'' AS MatchCode,
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
				'' AS BetCheck,
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
		b.*,
		SUBSTRING(c.username2, CHARINDEX('$', c.username2) + 1, LEN(c.username2) - CHARINDEX('$', c.username2)) AS Nickname,
		b.Stake			* e.USD AS StakeUSD,
		b.WinLost		* e.USD AS WinLostUSD,
		b.LicenseeWL	* e.USD AS LicenseeWLUSD,
		b.Comm			* e.USD AS CommUSD,
		b.PlayerComm	* e.USD AS PlayerCommUSD,
		b.OriginalStake	* e.USD AS OriginalStakeUSD,
		b.Stake			* e.EUR AS StakeEUR,
		b.WinLost		* e.EUR AS WinLostEUR,
		b.LicenseeWL	* e.EUR AS LicenseeWLEUR,
		b.Comm			* e.EUR AS CommEUR,
		b.PlayerComm	* e.EUR AS PlayerCommEUR,
		b.OriginalStake	* e.EUR AS OriginalStakeEUR,
		b.Stake			* e.GBP AS StakeGBP,
		b.WinLost		* e.GBP AS WinLostGBP,
		b.LicenseeWL	* e.GBP AS LicenseeWLGBP,
		b.Comm			* e.GBP AS CommGBP,
		b.PlayerComm	* e.GBP AS PlayerCommGBP,
		b.OriginalStake	* e.GBP AS OriginalStakeGBP
	FROM #Data AS b
		INNER JOIN dbo.Customer AS c (NOLOCK) ON b.custid = c.custid
		INNER JOIN #TempExchange AS e ON e.ExchangeDate = b.WinLostDate AND e.Exchangeid = b.Currency
	ORDER BY b.RowNum

	-- Get sub tickets
	DECLARE @BettransDetail TABLE (
		RefNo			BIGINT,
		Odds			MONEY,
		Stake			MONEY,
		Status			NVARCHAR(10),
		APositionTaking	SMALLMONEY,
		BetType			SMALLINT,
		BetTeam			NVARCHAR(10),
		StakeEUR		MONEY,
		StakeUSD		MONEY,
		StakeGBP		MONEY
	)

	-- Horse Racing
	IF EXISTS (	SELECT 1
				FROM #Data AS b
					INNER JOIN @SportBettype AS sbt ON b.bettype = sbt.Bettype
				WHERE sbt.ProductId = 2)
	BEGIN
		INSERT INTO @BettransDetail
		SELECT
			bm.refno,
			bm.odds,
			bm.stake,
			bm.status,
			bm.apositiontaking,
			bm.bettype,
			bm.betteam,
			bm.stake * e.EUR,
			bm.stake * e.USD,
			bm.stake * e.GBP
		FROM dbo.bettransm AS bm WITH (NOLOCK)
			INNER JOIN #Data AS b ON bm.refno = b.transid AND bm.custid = b.custid
			INNER JOIN #TempExchange AS e ON e.ExchangeDate = b.WinLostDate AND e.Exchangeid = b.Currency
			INNER JOIN @SportBettype AS sbt ON b.bettype = sbt.Bettype
			INNER JOIN @SportBettype AS sbtm ON bm.bettype = sbtm.Bettype
		WHERE sbt.ProductId = 2 AND sbtm.ProductId = 2

		INSERT INTO @BettransDetail
		SELECT
			bm.refno,
			bm.odds,
			bm.stake,
			bm.status,
			bm.apositiontaking,
			bm.bettype,
			bm.betteam,
			bm.stake * e.EUR,
			bm.stake * e.USD,
			bm.stake * e.GBP
		FROM dbo.bettransm14 AS bm WITH (NOLOCK)
			INNER JOIN #Data AS b ON bm.refno = b.transid AND bm.custid = b.custid
			INNER JOIN #TempExchange AS e ON e.ExchangeDate = b.WinLostDate AND e.Exchangeid = b.Currency
			INNER JOIN @SportBettype AS sbt ON b.bettype = sbt.Bettype
			INNER JOIN @SportBettype AS sbtm ON bm.bettype = sbtm.Bettype
		WHERE sbt.ProductId = 2 AND sbtm.ProductId = 2
	END

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
			bm.stake,
			bm.status,
			bm.apositiontaking,
			bm.bettype,
			bm.betteam,
			bm.stake * e.EUR,
			bm.stake * e.USD,
			bm.stake * e.GBP
		FROM dbo.bettransm AS bm WITH (NOLOCK)
			INNER JOIN #Data AS b ON bm.refno = b.RefNo AND bm.custid = b.custid
			INNER JOIN #TempExchange AS e ON e.ExchangeDate = b.WinLostDate AND e.Exchangeid = b.Currency
			INNER JOIN @SportBettype AS sbt ON b.bettype = sbt.Bettype
			INNER JOIN @SportBettype AS sbtm ON bm.bettype = sbtm.Bettype
		WHERE sbt.ProductId = 5
			AND sbt.EventType = 3
			AND sbtm.ProductId = 5
			AND sbtm.EventType = 3

		INSERT INTO @BettransDetail
		SELECT
			bm.refno,
			bm.odds,
			bm.stake,
			bm.status,
			bm.apositiontaking,
			bm.bettype,
			bm.betteam,
			bm.stake * e.EUR,
			bm.stake * e.USD,
			bm.stake * e.GBP
		FROM dbo.bettransm14 AS bm WITH (NOLOCK)
			INNER JOIN #Data AS b ON bm.refno = b.RefNo AND bm.custid = b.custid
			INNER JOIN #TempExchange AS e ON e.ExchangeDate = b.WinLostDate AND e.Exchangeid = b.Currency
			INNER JOIN @SportBettype AS sbt ON b.bettype = sbt.Bettype
			INNER JOIN @SportBettype AS sbtm ON bm.bettype = sbtm.Bettype
		WHERE sbt.ProductId = 5
			AND sbt.EventType = 3
			AND sbtm.ProductId = 5
			AND sbtm.EventType = 3
	END

	SELECT DISTINCT * FROM @BettransDetail
	ORDER BY RefNo, Bettype

	DROP TABLE #TempExchange
	DROP TABLE #Data
	DROP TABLE #TempData
END




/*
declare @p10 int
declare @p11 money
declare @p12 money
declare @p13 money
declare @p14 money
declare @p15 money
declare @p16 money
declare @p17 money
declare @p18 money
declare @p19 money
declare @p20 money
declare @p21 money
declare @p22 money
declare @p23 money
declare @p24 money
declare @p25 money
declare @p26 money
exec Lrf_BetList_SelWinLossByBetType @licenseeid=1,@userid=68,@CurrencyID=0,@LicenseeType=NULL,@bettype=9,
@PageSize=2147483646,@PageIndex=1,@totalrows=@p10 output,@SumWinlost=@p11 output,@SumLicenseeWL=@p12 output,
@SumComm=@p13 output,@SumPlayerComm=@p14 output,@SumWinlostUSD=@p15 output,@SumLicenseeWLUSD=@p16 output,@SumCommUSD=@p17 output,
@SumPlayerCommUSD=@p18 output,@SumWinlostEUR=@p19 output,@SumLicenseeWLEUR=@p20 output,@SumCommEUR=@p21 output,
@SumPlayerCommEUR=@p22 output,@SumWinlostGBP=@p23 output,@SumLicenseeWLGBP=@p24 output,@SumCommGBP=@p25 output,
@SumPlayerCommGBP=@p26 output,@FromDate='2016-02-24 00:00:00',@ToDate='2016-02-28 00:00:00',
@MoveBetsDay='2016-02-21 00:00:00',@BalanceUpDay='2016-02-20 00:00:00'
select @p10, @p11, @p12, @p13, @p14, @p15, @p16, @p17, @p18, @p19, @p20, @p21, @p22, @p23, @p24, @p25, @p26
*/

GO
GRANT	VIEW DEFINITION	ON	Lrf_BetList_SelWinLossByBetType	TO	vnteam
GO
GRANT	EXECUTE	ON	Lrf_BetList_SelWinLossByBetType	TO	bodbLicenseeNet
GO
