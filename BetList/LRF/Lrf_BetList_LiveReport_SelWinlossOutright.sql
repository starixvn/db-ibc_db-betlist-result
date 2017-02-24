ALTER PROCEDURE [dbo].[Lrf_BetList_LiveReport_SelWinlossOutright]
	@AgentList		VARCHAR(MAX),
	@FromDate		SMALLDATETIME,
	@ToDate			SMALLDATETIME,
	@ShowBA			BIT				= 0,
	@ShowSB			BIT				= 0,
	@MoveBetsDay	SMALLDATETIME,
	@PageSize		INT				= 1000,
	@PageIndex		INT				= 0
AS

/*
	Created: Henry@20120111
	Task: get bet tickets for outright, horse racing in Live Report
	DB: DBEXT.bodb02
	Original: [Lrf_BetList_SelWinlossOutright]

	Revisions:
		- 20120214@Jim: change table ExchangeDaily by function Lrf_f_GetExchangeDaily
		- 20120614@Jim: optimize code
		- 20120724@Jim: add playercomm value
		- 20121004@Jim: replace @currency input param by @currencyID
		- 20130305@Jim: remove Grand Total Row in the result data
		- 20130404@Jim: set default @ShowBA=0
		- 20130514@Jim: Restrict permission of Licensee Users by currency
		- 20130625@Jim: support to view currency UUS
		- 20141111@Winnie: Change from LicenseeCust to f_SelLicenseeCust
		- 20150126@Winnie: Add base currency GBP 
		- 20151203@Kos: Change odds, modds data type from SMALLMONEY to MONEY [Redmine: #48660]
		- 20170306@Kos: Support sub licensees [#Redmine: 71679]
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

	CREATE TABLE #AgWinlossOutright (
		SportType		INT,
		CustId			INT,
		BetType			SMALLINT,
		TransId			BIGINT,
		MatchCode		VARCHAR(50),
		HomeId			INT,
		AwayId			INT,
		Hdp1			SMALLMONEY,
		Hdp2			SMALLMONEY,
		Odds			MONEY,
		Status			NVARCHAR(50),
		Stake			MONEY,
		WinLost			MONEY,
		LicenseeWL		MONEY,
		Comm			MONEY,
		PlayerComm		MONEY,
		TransDate		DATETIME,
		BetTeam			NVARCHAR(50),
		LiveIndicator	BIT,
		LiveHomeScore	SMALLINT,
		LiveAwayScore	SMALLINT,
		LeagueId		INT,
		MatchId			INT, 
		Ip				VARCHAR(30),
		BetStatus		VARCHAR(50),
		IsNeutral		BIT,
		WinLostDate		DATETIME,
		Currency		SMALLINT,
		IsBA			INT
	)

	IF @Todate > @MoveBetsDay
	BEGIN
		IF @ShowBA = 1
		BEGIN
			INSERT INTO #AgWinlossOutright
			SELECT
				l.sporttype,
				b.custid,
				b.bettype,
				b.transid,
				m.matchcode,
				m.teamID,
				0,
				b.hdp1,
				b.hdp2,
				b.odds,
				b.status,
				b.stake,
				(b.winlost-actual_stake),
				0 AS LicenseeWL,
				b.comm,
				b.playercomm,
				b.transdate,
				b.betteam,
				b.liveindicator,
				b.livehomescore,
				b.liveawayscore,
				l.leagueID,
				b.matchid, 
				b.ip,
				NULL,
				CONVERT(BIT,0) AS IsNeutral,
				b.winlostdate,
				b.currency,
				1 AS isBA
			FROM
				dbo.bettrans AS b WITH (NOLOCK)
				INNER JOIN dbo.outright AS m WITH (NOLOCK) ON b.matchid = m.orid
				INNER JOIN dbo.League AS l WITH (NOLOCK) ON m.leagueID = l.leagueID
			WHERE
				b.recommend IN (SELECT CustId FROM @TempAg)
				AND b.currency IN (SELECT DISTINCT Currency FROM @TempAg)
				AND b.winlostdate BETWEEN @FromDate AND @ToDate
				AND b.bettype = 10
				AND b.tpositiontaking = 0
				AND b.statusID IN (111, 112, 113)
		END

		IF @ShowSB = 1
		BEGIN
			INSERT INTO #AgWinlossOutright
			SELECT
				l.sporttype,
				b.custid,
				b.bettype,
				b.transid,
				m.matchcode,
				m.teamID,
				0,
				b.hdp1,
				b.hdp2,
				b.odds,
				b.status,
				b.stake,
				(b.winlost-actual_stake),
				-(b.winlost-b.actual_stake) AS LicenseeWL,
				b.comm,
				b.playercomm,
				b.transdate,
				b.betteam,
				b.liveindicator,
				b.livehomescore,
				b.liveawayscore,
				l.leagueID,
				b.matchid, 
				b.ip,
				NULL,
				CONVERT(BIT,0) AS IsNeutral,
				b.winlostdate,
				b.currency,
				0 AS IsBA
			FROM
				dbo.bettrans AS b WITH (NOLOCK) 
				INNER JOIN dbo.outright AS m WITH (NOLOCK) ON b.matchid = m.orid
				INNER JOIN dbo.League AS l WITH (NOLOCK) ON m.leagueID = l.leagueID
			WHERE
				b.recommend IN (SELECT CustId FROM @TempAg)
				AND b.currency IN (SELECT DISTINCT Currency FROM @TempAg)
				AND b.winlostdate BETWEEN @FromDate AND @ToDate
				AND b.bettype = 10
				AND b.statusID IN (111, 112, 113)
				AND b.tpositiontaking <> 0
		END
	END

	IF @Fromdate <= @MoveBetsDay
	BEGIN
		IF @ShowBA = 1
		BEGIN
			INSERT INTO #AgWinlossOutright
			SELECT
				l.sporttype,
				b.custid,
				b.bettype,
				b.transid,
				m.matchcode,
				m.teamID,
				0,
				b.hdp1,
				b.hdp2,
				b.odds,
				b.status,
				b.stake,
				(b.winlost-actual_stake),
				0 AS LicenseeWL,
				b.comm,
				b.playercomm,
				b.transdate,
				b.betteam,
				b.liveindicator,
				b.livehomescore,
				b.liveawayscore,
				l.leagueID,
				b.matchid, 
				b.ip,
				NULL,
				CONVERT(BIT,0) AS IsNeutral,
				b.winlostdate,
				b.currency,
				1 AS IsBA
			FROM
				dbo.bettrans14 AS b WITH (NOLOCK) 
				INNER JOIN dbo.outright14 AS m WITH (NOLOCK) ON b.matchid = m.orid
				INNER JOIN dbo.League AS l WITH (NOLOCK) ON m.leagueID = l.leagueID
			WHERE
				b.recommend IN (SELECT CustId FROM @TempAg)
				AND b.currency IN (SELECT DISTINCT Currency FROM @TempAg)
				AND b.winlostdate BETWEEN @FromDate AND @ToDate
				AND b.bettype = 10
				AND b.statusID IN (111, 112, 113)
				AND b.tpositiontaking = 0
		END

		IF @ShowSB = 1
		BEGIN
			INSERT INTO #AgWinlossOutright
			SELECT
				l.sporttype,
				b.custid,
				b.bettype,
				b.transid,
				m.matchcode,
				m.teamID,
				0,
				b.hdp1,
				b.hdp2,
				b.odds,
				b.status,
				b.stake,
				(b.winlost-actual_stake),
				-(b.winlost-b.actual_stake)AS LicenseeWL,
				b.comm,
				b.playercomm,
				b.transdate,
				b.betteam,
				b.liveindicator,
				b.livehomescore,
				b.liveawayscore,
				l.leagueID,
				b.matchid, 
				b.ip,
				NULL,
				CONVERT(BIT,0) AS IsNeutral,
				b.winlostdate,
				b.currency,
				0 AS IsBA
			FROM
				dbo.bettrans14 AS b WITH (NOLOCK) 
				INNER JOIN dbo.outright14 AS m WITH (NOLOCK) ON b.matchid = m.orid
				INNER JOIN dbo.League AS l WITH (NOLOCK) ON m.leagueID = l.leagueID
			WHERE
				b.recommend IN (SELECT CustId FROM @TempAg)
				AND b.currency IN (SELECT DISTINCT Currency FROM @TempAg)
				AND b.winlostdate BETWEEN @FromDate AND @ToDate
				AND b.bettype = 10
				AND b.tpositiontaking <> 0
				AND b.statusID IN (111, 112, 113)
		END
	END

	DECLARE @RowStart INT,
		@RowEnd INT

	SELECT @PageIndex = @PageIndex - 1,
		@RowStart = @PageSize * @PageIndex + 1,
		@RowEnd = @RowStart + @PageSize - 1

	CREATE NONCLUSTERED INDEX IDX_Index_Ag ON #AgWinlossOutright(Currency)

	SELECT * INTO #TempExchange 
	FROM Lrf_f_GetExchangeDaily(@FromDate,@ToDate)
	WHERE exchangeid IN (SELECT DISTINCT Currency FROM #AgWinlossOutright)

	SELECT A.* 
	FROM (
			SELECT
				ROW_NUMBER() OVER(ORDER BY Transid) AS RowNum,
				b.*,
				c.username,
				SUBSTRING(c.username2, CHARINDEX('$', c.username2) + 1, LEN(c.username2) - CHARINDEX('$', c.username2)) AS Nickname,
				-- USD
				b.Stake			* e.USD AS StakeUSD,
				b.WinLost		* e.USD AS WinLostUSD,
				b.LicenseeWL	* e.USD AS LicenseeWLUSD,
				b.Comm			* e.USD AS CommUSD,
				b.PlayerComm	* e.USD AS PlayerCommUSD,
				-- EUR
				b.Stake			* e.EUR AS StakeEUR,
				b.WinLost		* e.EUR AS WinLostEUR,
				b.LicenseeWL	* e.EUR AS LicenseeWLEUR,
				b.Comm			* e.EUR AS CommEUR,
				b.PlayerComm	* e.EUR AS PlayerCommEUR,
				-- GBP
				b.Stake			* e.GBP AS StakeGBP,
				b.WinLost		* e.GBP AS WinLostGBP,
				b.LicenseeWL	* e.GBP AS LicenseeWLGBP,
				b.Comm			* e.GBP AS CommGBP,
				b.PlayerComm	* e.GBP AS PlayerCommGBP
			FROM #AgWinlossOutright AS b
				INNER JOIN dbo.customer AS c WITH(NOLOCK) ON c.custid = b.custid
				INNER JOIN #TempExchange AS e ON b.currency = e.exchangeID AND b.winlostdate = e.exchangeDate
		) A
	WHERE A.RowNum BETWEEN @RowStart AND @RowEnd

	DROP TABLE #AgWinlossOutright
	DROP TABLE #TempExchange
END

GO
GRANT EXECUTE ON [dbo].[Lrf_BetList_LiveReport_SelWinlossOutright] TO [bodbLicenseeNet]
GO
GRANT VIEW DEFINITION ON [dbo].[Lrf_BetList_LiveReport_SelWinlossOutright] TO [VNTeam] 