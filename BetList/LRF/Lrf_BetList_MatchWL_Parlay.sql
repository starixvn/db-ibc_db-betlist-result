set ANSI_NULLS ON
set QUOTED_IDENTIFIER ON
go


ALTER PROCEDURE [dbo].[Lrf_BetList_MatchWL_Parlay]
	@AgentList			VARCHAR(MAX),
	@BetType			INT				= 9,
	@ShowBA				BIT				= 0,
	@ShowSB				BIT				= 0,
	@FromDate			SMALLDATETIME,
	@ToDate				SMALLDATETIME,
	@MoveBetsDay		SMALLDATETIME,
	@PageSize			INT				= 1000,
	@PageIndex			INT				= 1,
	@TotalRows			INT				= 0 OUTPUT,
	@SumWinlost			MONEY			= 0 OUTPUT,
	@SumLicenseeWL		MONEY			= 0 OUTPUT,
	@SumComm			MONEY			= 0 OUTPUT,
	@SumPlayerComm		MONEY			= 0 OUTPUT,
	@SumWinlostUSD		MONEY			= 0 OUTPUT,
	@SumLicenseeWLUSD	MONEY			= 0 OUTPUT,
	@SumCommUSD			MONEY			= 0 OUTPUT,
	@SumPlayerCommUSD	MONEY			= 0 OUTPUT,
	@SumWinlostEUR		MONEY			= 0 OUTPUT,
	@SumLicenseeWLEUR	MONEY			= 0 OUTPUT,
	@SumCommEUR			MONEY			= 0 OUTPUT,
	@SumPlayerCommEUR	MONEY			= 0 OUTPUT,
	@SumWinlostGBP		MONEY			= 0 OUTPUT,
	@SumLicenseeWLGBP	MONEY			= 0 OUTPUT,
	@SumCommGBP			MONEY			= 0 OUTPUT,
	@SumPlayerCommGBP	MONEY			= 0 OUTPUT,
	@Sort				VARCHAR(100)	= 'TransID ASC'
AS

/*
	Created: Henry@20120111
	Task: Betlist for Parlay
	DB: DBEXT.bodb02
	Original: [Age_BetList_SelWinlossParlay_Ag]
	Revisions:
		- 20120214@Jim: change table ExchangeDaily by function Lrf_f_GetExchangeDaily
		- 20120319@Henry: show main transid for sub-ticket of system parlay
		- 20120614@Jim: optimize code 
		- 20120724@Jim: add playercomm value 
		- 20121004@Jim: replace @currency input param by @currencyID
		- 20130514@Jim: Restrict permission of Licensee Users by currency
		- 20140428@Hannah: Sort betlist
		- 20140516@Hannah: Fix bug Sort betlist
		- 20141111@Winnie: change from LicenseeCust to f_SelLicenseeCust
		- 20150128@Winnie: Add base currency GBP
		- 20151203@Kos: Change odds, modds data type from SMALLMONEY to MONEY [Redmine: #48660]
		- 20160414@Kos: Support Combo Parlay [#Redmine: 55282]
		- 20160516@Kos: Add sorting function [#Redmine: 57433]
		- 20170223@Kos: Support sub licensees [#Redmine: 71679]

	Param's Explanation:
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

	-- Use local variables to avoid bad params sniffing
	DECLARE @FDate	SMALLDATETIME, 
		@TDate		SMALLDATETIME

	SELECT @FDate = @FromDate,
		@TDate = @ToDate

	CREATE TABLE #Data (
		Username		NVARCHAR(50),
		Nickname		VARCHAR(50),
		CustId			INT,
		BetType			SMALLINT,
		RefNo			NVARCHAR(50),
		TransId			BIGINT,
		BetId			BIGINT,
		Hdp1			SMALLMONEY,
		Hdp2			SMALLMONEY,
		Odds			MONEY,
		Modds			MONEY,
		Status			NVARCHAR(50),
		Stake			MONEY,
		Actual_Stake	MONEY,
		WinLost			MONEY,
		LicenseeWL		MONEY,
		Comm			MONEY,
		PlayerComm		MONEY,
		TransDate		DATETIME,
		WinLostDate		DATETIME,
		BetTeam			NVARCHAR(25),
		LiveIndicator	BIT,
		LiveHomeScore	SMALLINT,
		LiveAwayScore	SMALLINT,
		Ip				VARCHAR(30),
		IsNeutral		BIT,
		Currency		SMALLINT,
		IsBA			INT,
		AWinLost		MONEY,
		BetCheck		NVARCHAR(50)
	)

	IF @TDate > @MoveBetsDay
	BEGIN
		IF @ShowBA = 1
		BEGIN
			INSERT INTO #Data
			SELECT
				b.username,
				'' AS Nickname,
				b.custid,
				b.bettype,
				CONVERT(NVARCHAR, b.refno),
				CASE
					WHEN bettype <> 29 THEN b.transid
					ELSE CASE WHEN ISNULL(b.betid, 0) = 0 THEN b.transid ELSE betid END
				END AS transid,
				ISNULL(b.betid, 0),
				b.hdp1,
				b.hdp2,
				b.odds,
				b.modds,
				b.status,
				b.stake,
				b.actual_stake,
				(b.winlost-actual_stake),
				0 AS LicenseeWL,
				b.comm,
				b.playercomm,
				b.transdate,
				b.winlostdate,
				b.betteam,
				b.liveindicator,
				b.livehomescore,
				b.liveawayscore,
				b.ip,
				CONVERT(BIT,0) AS IsNeutral,
				b.currency,
				1 AS isBA,
				b.awinlost,
				ISNULL(b.betcheck, '') AS BetCheck
			FROM dbo.bettrans AS b WITH (NOLOCK)
			WHERE
				b.recommend IN (SELECT CustId FROM @TempAg)
				AND b.currency IN (SELECT DISTINCT Currency FROM @TempAg)
				AND b.winlostdate BETWEEN @FDate AND @TDate
				AND b.bettype = @BetType
				AND b.matchid = @BetType
				AND b.tpositiontaking = 0
				AND b.statusID IN (111, 112, 113)
		END

		IF @ShowSB = 1
		BEGIN
			INSERT INTO #Data
			SELECT
				b.username,
				'' AS Nickname,
				b.custid,
				b.bettype,
				CONVERT(NVARCHAR, b.refno),
				CASE
					WHEN bettype <> 29 THEN b.transid
					ELSE CASE WHEN ISNULL(b.betid, 0) = 0 THEN b.transid ELSE betid END
				END AS transid,
				ISNULL(b.betid, 0),
				b.hdp1,
				b.hdp2,
				b.odds,
				b.modds,
				b.status,
				b.stake,
				b.actual_stake,
				(b.winlost - actual_stake),
				 -(b.winlost - b.actual_stake) AS LicenseeWL,
				b.comm,
				b.playercomm,
				b.transdate,
				b.winlostdate,
				b.betteam,
				b.liveindicator,
				b.livehomescore,
				b.liveawayscore,
				b.ip,
				CONVERT(BIT,0) AS IsNeutral,
				b.currency,
				0 AS isBA,
				b.awinlost,
				ISNULL(b.betcheck, '') AS BetCheck
			FROM dbo.bettrans AS b WITH (NOLOCK)
			WHERE
				b.recommend IN (SELECT CustId FROM @TempAg)
				AND b.currency IN (SELECT DISTINCT Currency FROM @TempAg)
				AND b.winlostdate BETWEEN @FDate AND @TDate
				AND b.bettype = @Bettype
				AND b.matchid = @Bettype
				AND b.tpositiontaking <> 0
				AND b.statusID IN (111, 112, 113)
		END
	END

	IF @FDate <= @MoveBetsDay
	BEGIN
		IF @ShowBA = 1
		BEGIN
			INSERT INTO #Data 
			SELECT
				b.username,
				'' AS Nickname,
				b.custid,
				b.bettype,
				CONVERT(NVARCHAR, b.refno),
				CASE
					WHEN bettype <> 29 THEN b.transid
					ELSE CASE WHEN ISNULL(b.betid, 0) = 0 THEN b.transid ELSE betid END
				END AS transid,
				ISNULL(b.betid, 0),
				b.hdp1,
				b.hdp2,
				b.odds,
				b.modds,
				b.status,
				b.stake,
				b.actual_stake,
				(b.winlost-actual_stake),
				0 AS LicenseeWL,
				b.comm,
				b.playercomm,
				b.transdate,
				b.winlostdate,
				b.betteam,
				b.liveindicator,
				b.livehomescore,
				b.liveawayscore,
				b.ip,
				CONVERT(BIT,0) AS IsNeutral,
				b.currency,
				1 AS IsBA,
				b.awinlost,
				ISNULL(b.betcheck, '') AS BetCheck
			FROM dbo.bettrans14 AS b WITH (NOLOCK)
			WHERE
				b.recommend IN (SELECT CustId FROM @TempAg)
				AND b.currency IN (SELECT DISTINCT Currency FROM @TempAg)
				AND b.winlostdate BETWEEN @FDate AND @TDate
				AND b.bettype = @BetType
				AND b.matchid = @BetType
				AND b.tpositiontaking = 0
				AND b.statusID IN (111, 112, 113)
		END

		IF @ShowSB = 1
		BEGIN
			INSERT INTO #Data
			SELECT
				b.username,
				'' AS Nickname,
				b.custid,
				b.bettype,
				CONVERT(NVARCHAR, b.refno),
				CASE
					WHEN bettype <> 29 THEN b.transid
					ELSE CASE WHEN ISNULL(b.BetID,0) = 0 THEN b.transid ELSE betid END
				END AS transid,
				ISNULL(b.betid, 0),
				b.hdp1,
				b.hdp2,
				b.odds,
				b.modds,
				b.status,
				b.stake,
				b.actual_stake,
				(b.winlost - actual_stake),
				-(b.winlost - b.actual_stake) AS LicenseeWL,
				b.comm,
				b.playercomm,
				b.transdate,
				b.winlostdate,
				b.betteam,
				b.liveindicator,
				b.livehomescore,
				b.liveawayscore,
				b.ip,
				CONVERT(BIT,0) AS IsNeutral,
				b.currency,
				0 AS IsBA,
				b.awinlost,
				ISNULL(b.betcheck, '') AS BetCheck
			FROM dbo.bettrans14 AS b WITH (NOLOCK)
			WHERE
				b.recommend IN (SELECT CustId FROM @TempAg)
				AND b.currency IN (SELECT DISTINCT Currency FROM @TempAg)
				AND b.winlostdate BETWEEN @FDate AND @TDate
				AND b.bettype = @Bettype
				AND b.matchid = @Bettype
				AND b.tpositiontaking <> 0
				AND b.statusID IN (111, 112, 113)
		END
	END

	DECLARE @RowStart INT,
		@RowEnd INT

	SELECT @PageIndex = @PageIndex - 1,
		@RowStart = @PageSize * @PageIndex + 1,
		@RowEnd = @RowStart + @PageSize - 1

	CREATE NONCLUSTERED INDEX IDX_Index_Ag ON #Data (Currency)

	SELECT * INTO #TempExchange 
	FROM Lrf_f_GetExchangeDaily(@FDate, @TDate)
	WHERE exchangeid IN (SELECT DISTINCT Currency FROM #Data)

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
	FROM #Data AS b
		INNER JOIN #TempExchange AS e ON b.Currency = e.exchangeID AND b.WinLostDate = e.exchangeDate
		INNER JOIN dbo.customer AS c WITH (NOLOCK) ON c.custid = b.CustId

	UPDATE #Data
	SET Nickname = SUBSTRING(c.username2, CHARINDEX('$', c.username2) + 1, LEN(c.username2) - CHARINDEX('$', c.username2))
	FROM #Data AS b
		INNER JOIN dbo.Customer AS c WITH (NOLOCK) ON b.CustId = c.custid

	CREATE TABLE #PagingData (
		RowNum			INT,
		Username		NVARCHAR(50),
		Nickname		VARCHAR(50),
		CustId			INT,
		BetType			SMALLINT,
		RefNo			NVARCHAR(50),
		TransId			BIGINT,
		BetId			BIGINT,
		Hdp1			SMALLMONEY,
		Hdp2			SMALLMONEY,
		Odds			MONEY,
		Modds			MONEY,
		Status			NVARCHAR(50),
		Stake			MONEY,
		Actual_Stake	MONEY,
		WinLost			MONEY,
		LicenseeWL		MONEY,
		Comm			MONEY,
		PlayerComm		MONEY,
		TransDate		DATETIME,
		WinLostDate		DATETIME,
		BetTeam			NVARCHAR(25),
		LiveIndicator	BIT,
		LiveHomeScore	SMALLINT,
		LiveAwayScore	SMALLINT,
		Ip				VARCHAR(30),
		IsNeutral		BIT,
		Currency		SMALLINT,
		IsBA			INT,
		AWinLost		MONEY,
		BetCheck		NVARCHAR(50)
	)

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
		'INSERT INTO #PagingData
		SELECT A.*
		FROM
		(
			SELECT
				ROW_NUMBER() OVER (ORDER BY ' + @SortExp + ') AS RowNum,
				b.* 
			FROM #Data AS b
				INNER JOIN #TempExchange AS e ON e.exchangeid = b.Currency AND e.ExchangeDate = b.WinLostDate
		) A
		WHERE A.RowNum BETWEEN ' + CAST(@RowStart AS VARCHAR(50)) + ' AND ' + CAST(@RowEnd AS VARCHAR(50))
		+ ' ORDER BY A.RowNum'

	EXEC sp_executesql @sql

	DROP TABLE #Data

	SELECT
		b.*,
		'' AS BetStatus,
		'' AS MatchCode,
		0 AS HomeId,
		0 AS AwayId,
		0 AS LeagueId,
		0 AS MatchId,
		0 AS SportType,
		-- USD
		b.Stake			* e.USD AS StakeUSD,
		b.Actual_Stake	* e.USD AS Actual_StakeUSD,
		b.WinLost		* e.USD AS WinLostUSD,
		b.LicenseeWL	* e.USD AS LicenseeWLUSD,
		b.Comm			* e.USD AS CommUSD,
		b.PlayerComm	* e.USD AS PlayerCommUSD,
		-- EUR
		b.Stake			* e.EUR AS StakeEUR,
		b.Actual_Stake	* e.EUR AS Actual_StakeEUR,
		b.WinLost		* e.EUR AS WinLostEUR,
		b.LicenseeWL	* e.EUR AS LicenseeWLEUR,
		b.Comm			* e.EUR AS CommEUR,
		b.PlayerComm	* e.EUR AS PlayerCommEUR,
		-- GBP
		b.Stake			* e.GBP AS StakeGBP,
		b.Actual_Stake	* e.GBP AS Actual_StakeGBP,
		b.WinLost		* e.GBP AS WinLostGBP,
		b.LicenseeWL	* e.GBP AS LicenseeWLGBP,
		b.Comm			* e.GBP AS CommGBP,
		b.PlayerComm	* e.GBP AS PlayerCommGBP
	FROM #PagingData AS b
		INNER JOIN #TempExchange AS e ON e.ExchangeDate = b.WinLostDate AND e.exchangeid = b.Currency
	ORDER BY b.RowNum

	DROP TABLE #PagingData
	DROP TABLE #TempExchange
END


GO
GRANT EXECUTE ON [dbo].[Lrf_BetList_MatchWL_Parlay] TO [bodbLicenseeNet]
GO
GRANT VIEW DEFINITION ON [dbo].[Lrf_BetList_MatchWL_Parlay] TO [vnteam] 