ALTER PROCEDURE [dbo].[Lrf_BetList_LiveReport_SelWinlossParlay]
	@AgentList		VARCHAR(MAX),
	@BetType		INT				= 9,
	@ShowBA			BIT				= 0,
	@ShowSB			BIT				= 0,
	@FromDate		SMALLDATETIME,
	@ToDate			SMALLDATETIME,
	@MoveBetsDay	SMALLDATETIME,
	@PageSize		INT				= 1000,
	@PageIndex		INT				= 1,
	@Sort			VARCHAR(20)		= 'Transid DESC',
	@LiveIndicator	INT				= 1
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
		- 20130305@Jim: remove Grand total row in the result data
		- 20130404@Jim: set default @ShowBA=0
		- 20130514@Jim: Restrict permission of Licensee Users by currency
		- 20130625@Jim: Support to view currency UUS
		- 20140520@Hannah: Sort betlist
		- 20140602@Hannah: Separate Live/ Non - Live data in Live Report
		- 20141111@Winnie: Change from LicenseeCust to f_SelLicenseeCust
		- 20150126@Winnie: Add base currency GBP 
		- 20151203@Kos: Change odds, modds data type from SMALLMONEY to MONEY [Redmine: #48660]
		- 20160413@Kos: Support Combo Parlay [#Redmine: 55282]
		- 20170306@Kos: Support sub licensees [#Redmine: 71679]
		- 20170531@Kos: Prevent data duplication during Move Bet process [#Redmine: 77065]

	Param's Explanation:
		@Liveindicator : indicate that whether the report will get live data or not
			+ 0: Non - Live data only
			+ 1: Live data only
			+ 2: All
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

	CREATE TABLE #AgWinlossMP (
		Username		NVARCHAR(50),
		CustId			INT,
		BetType			SMALLINT,
		RefNo			BIGINT,
		TransId			BIGINT,
		BetId			BIGINT,
		Hdp1			SMALLMONEY,
		Hdp2			SMALLMONEY,
		Odds			MONEY,
		MOdds			MONEY,
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
		BetCheck		NVARCHAR(50),
		IsBA			INT
	)

	DECLARE @TempFromDate	SMALLDATETIME,
		@TempToDate			SMALLDATETIME

	IF @Todate > @MoveBetsDay
	BEGIN
		IF @FromDate <= @MoveBetsDay
			SET @TempFromDate =  DATEADD(DAY, 1, @MoveBetsDay)
		ELSE
			SET @TempFromDate = @FromDate

		IF @ShowBA = 1
		BEGIN
			INSERT INTO #AgWinlossMP
			SELECT
				b.username,
				b.custid,
				b.bettype,
				b.refno,
				CASE
					WHEN b.bettype <> 29 THEN b.transid
					ELSE CASE WHEN ISNULL(b.betid, 0) = 0 THEN b.transid ELSE b.betid END
				END AS transid,
				ISNULL(b.betid, 0),
				b.hdp1,
				b.hdp2,
				b.odds,
				b.modds,
				b.status,
				b.stake,
				b.actual_stake,
				(b.winlost - b.actual_stake) AS WinLost,
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
				ISNULL(b.betcheck, '') AS BetCheck,
				1 AS isBA
			FROM dbo.bettrans AS b WITH (NOLOCK)
			WHERE
				b.recommend IN (SELECT CustId FROM @TempAg)
				AND b.currency IN (SELECT DISTINCT Currency FROM @TempAg)
				AND b.winlostdate BETWEEN @TempFromDate AND @ToDate
				AND b.bettype = @BetType
				AND b.matchid = @BetType
				AND b.tpositiontaking = 0
				AND b.statusID IN (111, 112, 113)
				AND ((@LiveIndicator = 0 AND b.livehomescore = 0)
					OR (@LiveIndicator = 1 AND b.livehomescore = 1)
					OR (@LiveIndicator = 2))
		END

		IF @ShowSB = 1
		BEGIN
			INSERT INTO #AgWinlossMP
			SELECT
				b.username,
				b.custid,
				b.bettype,
				b.refno,
				CASE
					WHEN b.bettype <> 29 THEN b.transid
					ELSE CASE WHEN ISNULL(b.betid, 0) = 0 THEN b.transid ELSE b.betid END
				END AS transid,
				ISNULL(b.betid, 0),
				b.hdp1,
				b.hdp2,
				b.odds,
				b.modds,
				b.status,
				b.stake,
				b.actual_stake,
				(b.winlost - b.actual_stake) AS WinLost,
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
				ISNULL(b.betcheck, '') AS BetCheck,
				0 AS isBA
			FROM dbo.bettrans AS b WITH (NOLOCK)
			WHERE
				b.recommend IN (SELECT CustId FROM @TempAg)
				AND b.currency IN (SELECT DISTINCT Currency FROM @TempAg)
				AND b.winlostdate BETWEEN @TempFromDate AND @ToDate
				AND b.bettype = @Bettype
				AND b.matchid = @Bettype
				AND b.tpositiontaking <> 0
				AND b.statusID IN (111, 112, 113)
				AND ((@LiveIndicator = 0 AND b.livehomescore = 0)
					OR (@LiveIndicator = 1 AND b.livehomescore = 1)
					OR (@LiveIndicator = 2))
		END
	END

	IF @Fromdate <= @MoveBetsDay
	BEGIN
		IF @ToDate >= @MoveBetsDay
			SET @TempToDate = @MoveBetsDay
		ELSE
			SET @TempToDate = @ToDate

		IF @ShowBA = 1
		BEGIN
			INSERT INTO #AgWinlossMP
			SELECT
				b.username,
				b.custid,
				b.bettype,
				b.refno,
				CASE
					WHEN b.bettype <> 29 THEN b.transid
					ELSE CASE WHEN ISNULL(b.betid, 0) = 0 THEN b.transid ELSE b.betid END
				END AS transid,
				ISNULL(b.betid, 0),
				b.hdp1,
				b.hdp2,
				b.odds,
				b.modds,
				b.status,
				b.stake,
				b.actual_stake,
				(b.winlost - b.actual_stake) AS WinLost,
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
				ISNULL(b.betcheck, '') AS BetCheck,
				1 AS IsBA
			FROM dbo.bettrans14 AS b WITH (NOLOCK)
			WHERE
				b.recommend IN (SELECT CustId FROM @TempAg)
				AND b.currency IN (SELECT DISTINCT Currency FROM @TempAg)
				AND b.winlostdate BETWEEN @FromDate AND @TempToDate
				AND b.bettype = @BetType
				AND b.matchid = @BetType
				AND b.tpositiontaking = 0
				AND b.statusID IN (111, 112, 113)
				AND ((@LiveIndicator = 0 AND b.livehomescore = 0)
					OR (@LiveIndicator = 1 AND b.livehomescore = 1)
					OR (@LiveIndicator = 2))
		END

		IF @ShowSB = 1
		BEGIN
			INSERT INTO #AgWinlossMP
			SELECT
				b.username,
				b.custid,
				b.bettype,
				b.refno,
				CASE
					WHEN b.bettype <> 29 THEN b.transid
					ELSE CASE WHEN ISNULL(b.betid, 0) = 0 THEN b.transid ELSE b.betid END
				END AS transid,
				ISNULL(b.betid, 0),
				b.hdp1,
				b.hdp2,
				b.odds,
				b.modds,
				b.status,
				b.stake,
				b.actual_stake,
				(b.winlost - b.actual_stake) AS WinLost,
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
				ISNULL(b.betcheck, '') AS BetCheck,
				0 AS IsBA
			FROM dbo.bettrans14 AS b WITH (NOLOCK)
			WHERE
				b.recommend IN (SELECT CustId FROM @TempAg)
				AND b.currency IN (SELECT DISTINCT Currency FROM @TempAg)
				AND b.winlostdate BETWEEN @FromDate AND @TempToDate
				AND b.bettype = @Bettype
				AND b.matchid = @Bettype
				AND b.tpositiontaking <> 0
				AND b.statusID IN (111, 112, 113)
				AND ((@LiveIndicator = 0 AND b.livehomescore = 0)
					OR (@LiveIndicator = 1 AND b.livehomescore = 1)
					OR (@LiveIndicator = 2))
		END
	END

	DECLARE @RowStart INT,
		@RowEnd INT

	SELECT @PageIndex = @PageIndex - 1,
		@RowStart = @PageSize * @PageIndex + 1,
		@RowEnd = @RowStart + @PageSize - 1

	CREATE NONCLUSTERED INDEX IDX_Index_Ag ON #AgWinlossMP (Currency)

	SELECT * INTO #TempExchange
	FROM Lrf_f_GetExchangeDaily(@FromDate, @ToDate)
	WHERE exchangeid IN (SELECT DISTINCT Currency FROM #AgWinlossMP)

	DECLARE @sql NVARCHAR(2500)
	DECLARE @SortTemp VARCHAR(250)

	IF @Sort LIKE '%USD%' OR @Sort LIKE '%EUR%' OR @Sort LIKE '%GBP%'
	BEGIN
		DECLARE @CharIndex INT

		SELECT @CharIndex = CHARINDEX( ' ', @Sort, 1)
		SELECT @SortTemp = SUBSTRING(@Sort, 1, @CharIndex - 4) + '*e.' + SUBSTRING(@Sort, @CharIndex - 3, 4) + SUBSTRING(@Sort, @CharIndex + 1, LEN(@Sort))
	END
	ELSE
	BEGIN
		SET @SortTemp = @Sort
	END

	SELECT @sql = 
		'SELECT A.*,'''' betstatus, '''' matchcode, 0 homeid, 0 awayid, 0 leagueid, 0 matchid, 0 sporttype
		FROM
		(
			SELECT
				ROW_NUMBER() OVER(ORDER BY ' + @SortTemp + ') AS RowNum,
				b.*,
				SUBSTRING(c.username2, CHARINDEX(''$'',c.username2) + 1, LEN(c.username2) - CHARINDEX(''$'',c.username2)) AS nickname,
				--USD
				stake * e.USD stakeUSD,
				actual_stake * e.USD actual_stakeUSD,
				winlost * e.USD winlostUSD,
				LicenseeWL* e.USD LicenseeWLUSD,
				comm * e.USD commUSD,
				playercomm*e.USD PlayerCommUSD,
				--EUR
				stake * e.EUR stakeEUR,
				actual_stake * e.EUR actual_stakeEUR,
				winlost * e.EUR winlostEUR,
				LicenseeWL * e.EUR LicenseeWLEUR,
				comm * e.EUR commEUR,
				playercomm*e.EUR playercommEUR,
				--GBP
				stake * e.GBP stakeGBP,
				actual_stake * e.GBP actual_stakeGBP,
				winlost * e.GBP winlostGBP,
				LicenseeWL * e.GBP LicenseeWLGBP,
				comm * e.GBP commGBP,
				playercomm*e.GBP playercommGBP
			FROM #AgWinlossMP AS b
				INNER JOIN dbo.Customer AS c WITH (NOLOCK) ON c.custid = b.custid
				INNER JOIN #TempExchange e ON b.currency = e.exchangeID AND b.winlostdate = e.exchangeDate
		) A WHERE A.RowNum BETWEEN ' + CAST(@RowStart AS VARCHAR(50)) + ' AND ' + CAST(@RowEnd AS VARCHAR(50))
		+' ORDER BY A.RowNum'

	EXEC (@sql)

	DROP TABLE #AgWinlossMP
	DROP TABLE #TempExchange
END



GO
GRANT EXECUTE ON [dbo].[Lrf_BetList_LiveReport_SelWinlossParlay] TO [bodbLicenseeNet]
GO
GRANT VIEW DEFINITION ON [dbo].[Lrf_BetList_LiveReport_SelWinlossParlay] TO [vnteam] 