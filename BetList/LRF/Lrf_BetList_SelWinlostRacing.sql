set ANSI_NULLS ON
set QUOTED_IDENTIFIER ON
go
USE bodb02
GO

ALTER PROCEDURE [dbo].[Lrf_BetList_SelWinlostRacing]
	@LicenseeId			INT,
	@UserId				INT,
	@LicenseeType		VARCHAR(100)	= NULL,
	@CurrencyId			INT				= 0,
	@Date				DATETIME,
	@LeagueId			INT,
	@RaceNo				VARCHAR(10),
	@MoveBetsDay		SMALLDATETIME,
	@PageSize			INT				= 1000,
	@PageIndex			INT				= 1,
	@TotalRows			INT				= 0 OUTPUT,
	@SumWinLost			MONEY			= 0 OUTPUT,
	@SumStake			MONEY			= 0 OUTPUT,
	@SumLicenseeWL		MONEY			= 0 OUTPUT,
	@SumComm			MONEY			= 0 OUTPUT,
	@SumPlayerComm		MONEY			= 0 OUTPUT,
	@SumWinLostEUR		MONEY			= 0 OUTPUT,
	@SumStakeEUR		MONEY			= 0 OUTPUT,
	@SumLicenseeWLEUR	MONEY			= 0 OUTPUT,
	@SumCommEUR			MONEY			= 0 OUTPUT,
	@SumPlayerCommEUR	MONEY			= 0 OUTPUT,
	@SumWinLostUSD		MONEY			= 0 OUTPUT,
	@SumStakeUSD		MONEY			= 0 OUTPUT,
	@SumLicenseeWLUSD	MONEY			= 0 OUTPUT,
	@SumCommUSD			MONEY			= 0 OUTPUT,
	@SumPlayerCommUSD	MONEY			= 0 OUTPUT,
	@SumWinLostGBP		MONEY			= 0 OUTPUT,
	@SumStakeGBP		MONEY			= 0 OUTPUT,
	@SumLicenseeWLGBP	MONEY			= 0 OUTPUT,
	@SumCommGBP			MONEY			= 0 OUTPUT,
	@SumPlayerCommGBP	MONEY			= 0 OUTPUT
AS

/*
	Created by: Henry
	Date: 2011-09-21
	Task: Racing Detailed Bet List
	DB: DBACC.bodb02

	Revisions:
		- 20111010@Henry: Change column name
		- 20120214@Jim: change to use table ExchangeDaily by use function Lrf_f_GetExchangeDaily
		- 20120614@Jim: Optimize code
		- 20120726@Jim: Add playercomm value
		- 20121004@Jim: Replace @currencyname input param by @currencyID
		- 20130123@Daniel: Change link server alias
		- 20130305@Jim: Change input param @winlostdate by @date 
		- 20130402@Jim: Support base currency by USD
		- 20130514@Jim: Restrict permission of Licensee Users by currency
		- 20141111@Winnie: change from LicenseeCust to f_SelLicenseeCust
		- 20150127@Winnie: add base currency GBP
		- 20150409@Winnie: Apply sport bettype matrix
		- 20151203@Kos: Change odds, modds data type from SMALLMONEY to MONEY [Redmine: #48660]
		- 20161004@Kos: Add product bet type range for sub tables [Redmine: #65045]

	Param's Explanation:
*/

BEGIN
	SET NOCOUNT ON

	-- Get Sport Bettype Matrix
	DECLARE @SportBettype TABLE(ProductID INT,Bettype INT,EventType INT)

	DECLARE @IsTest BIT = 0

	SELECT @IsTest = dbo.f_CheckSPVersion(@@PROCID)

	INSERT INTO @SportBettype
	SELECT ProductID, BetType, EventType
	FROM dbo.f_SportBettypeMatrix_Sel (2, 0, 0, 2, '', '', @IsTest)

	SELECT CurrencyID,
		LicenseeID
	INTO #Currency
	FROM DBLIC.bodb_licensee.dbo.CurrencyUser WITH (NOLOCK)
	WHERE usrID = @userID
		AND LicenseeID = @LicenseeID 
		AND SystemID = 1
		AND isActive = 1
		AND (@CurrencyID = 0
			OR (@CurrencyID <> 0 AND CurrencyID = @CurrencyID))

	DECLARE @TempAg AS TABLE (CustId INT)

	INSERT INTO @TempAg(CustId)
	SELECT CustId
	FROM dbo.custInfo WITH ( NOLOCK )
	WHERE custid IN (
			SELECT DISTINCT CustID
			FROM OPENQUERY(DBLIC, 'SELECT * FROM bodb_licensee.dbo.f_SelLicenseeCust(0)') lc
				INNER JOIN  #currency c ON lc.LicenseeID = c.LicenseeID AND lc.Currency = c.CurrencyID
			WHERE [Description] = COALESCE(@LicenseeType, [Description]) )
				AND RoleId = 2

	DECLARE @LicenseeName VARCHAR(50)

	SELECT @LicenseeName = LicenseeName
	FROM DBLIC.bodb_Licensee.dbo.Licensees WITH (NOLOCK)
	WHERE LicenseeID = @LicenseeID
	
	DECLARE @str_compare VARCHAR(30)
	
	SELECT @str_compare = @LicenseeName + '$'

	CREATE TABLE #DataTmp (
		Username		NVARCHAR(50),
		Nickname		NVARCHAR(50),
		CustId			INT,
		TransId			BIGINT,
		Race			VARCHAR(50),
		TransDate		DATETIME,
		BetType			SMALLINT,
		MatchId			INT,
		WinOdds			MONEY,
		PlaceOdds		MONEY,
		Odds			MONEY,
		Stake			MONEY,
		WinLost			MONEY,
		LicenseeWL		MONEY,
		Comm			MONEY,
		PlayerComm		MONEY,
		WinStatus		VARCHAR(20),
		PlaceStatus		VARCHAR(20),
		Status			NVARCHAR(50),
		HomeId			INT,
		AwayId			INT,
		MatchCode		VARCHAR(50),
		VirtualRate		FLOAT,
		IsShowOTExRate	BIT,
		Currency		INT,
		WinLostDate		SMALLDATETIME,
		LeagueId		INT
	)

	IF @date > @MoveBetsDay
	BEGIN
		INSERT INTO #DataTmp
		SELECT
			b.username,
			REPLACE(c.username2, @str_compare, '') AS Nickname,
			b.custid,
			b.transid,
			o.groupmatch AS race,
			b.transdate,
			b.bettype,
			b.matchid,
			b.hdp1 winOdds,
			b.hdp2 placeOdds,
			b.odds,
			b.stake,
			(b.winlost - b.actual_stake) winlost,
			(b.awinlost + b.mwinlost + b.swinlost) AS LicenseeWL,
			b.comm,
			b.playercomm,
			CASE b.livehomescore WHEN 2 THEN 'WON' WHEN 4 THEN 'LOSE' ELSE '' END winStatus,
			CASE b.liveawayscore WHEN 2 THEN 'WON' WHEN 4 THEN 'LOSE' ELSE 'Refund' END placeStatus,
			b.status,
			o.teamid,
			0,
			o.matchcode,
			b.virtualrate,
			CASE WHEN b.currency2 IS NULL THEN CONVERT(BIT,0) ELSE CONVERT(BIT,1) END AS isShowOTExRate,
			b.currency,
			b.winlostdate,
			o.leagueid
		FROM dbo.bettrans AS b WITH (NOLOCK)
			INNER JOIN dbo.outright AS o WITH (NOLOCK) ON b.matchid = o.orid
			INNER JOIN dbo.customer AS c WITH (NOLOCK) ON b.custid = c.custid
			INNER JOIN @SportBettype AS sbt ON sbt.Bettype = b.bettype
		WHERE b.ruben = 1
			AND b.statusID NOT IN (101, 102, 103, 121)
			AND b.currency = @currencyID
			AND b.winlostdate = @date
			AND o.leagueid = @leagueid
			AND o.groupmatch = @raceNo
			AND b.recommend IN (SELECT custid FROM @TempAg)
			AND ((@CurrencyID = 0 AND b.currency IN (SELECT currencyId FROM #currency))
				OR (@CurrencyID <> 0 AND b.Currency = @CurrencyID))
		ORDER BY b.username
	END
	ELSE
	BEGIN
		INSERT INTO #DataTmp
		SELECT
			b.username,
			REPLACE(c.username2, @str_compare, '') AS Nickname,
			b.custid,
			b.transid,
			o.groupmatch AS race,
			b.transdate,
			b.bettype,
			b.matchid,
			b.hdp1 winOdds,
			b.hdp2 placeOdds,
			b.odds,
			b.stake,
			(b.winlost - b.actual_stake) winlost,
			(b.awinlost + b.mwinlost + b.swinlost) AS LicenseeWL,
			b.comm,
			b.playercomm,
			CASE b.livehomescore WHEN 2 THEN 'WON' WHEN 4 THEN 'LOSE' ELSE '' END winStatus,
			CASE b.liveawayscore WHEN 2 THEN 'WON' WHEN 4 THEN 'LOSE' ELSE 'Refund' END placeStatus,
			b.status,
			o.teamid,
			0,
			o.matchcode,
			b.virtualrate,
			CASE WHEN b.currency2 IS NULL THEN CONVERT(BIT,0) ELSE CONVERT(BIT,1) END AS isShowOTExRate,
			b.currency,
			b.winlostdate,
			o.leagueid
		FROM dbo.bettrans14 AS b WITH (NOLOCK)
			INNER JOIN dbo.outright14 AS o WITH (NOLOCK) ON b.matchid = o.orid
			INNER JOIN dbo.customer AS c WITH (NOLOCK) ON b.custid = c.custid
			INNER JOIN @SportBettype AS sbt ON sbt.Bettype = b.bettype
		WHERE b.ruben = 1
			AND b.statusID NOT IN (101, 102, 103, 121)
			AND b.currency = @currencyID
			AND b.winlostdate = @date
			AND o.leagueid = @leagueid
			AND o.groupmatch = @raceNo
			AND b.recommend IN (SELECT custid FROM @TempAg)
			AND ((@CurrencyID = 0 AND b.currency IN (SELECT currencyId FROM #currency))
				OR (@CurrencyID <> 0 AND b.Currency = @CurrencyID))
		ORDER BY b.username
	END

	DECLARE @RowStart INT,
		@RowEnd INT

	SELECT @PageIndex = @PageIndex - 1,
		@RowStart = @PageSize * @PageIndex + 1,
		@RowEnd = @RowStart + @PageSize - 1

	CREATE NONCLUSTERED INDEX IDX_Index_Ag ON #DataTmp(Currency)

	SELECT * INTO #TempExchange
	FROM Lrf_f_GetExchangeDaily(@date,@date)
	WHERE exchangeid IN (SELECT DISTINCT Currency FROM #DataTmp)

	SELECT
		@TotalRows		= COUNT(b.TransId),
		@SumWinlost		= SUM(ISNULL(b.WinLost, 0)),
		@SumStake		= SUM(ISNULL(b.Stake, 0)),
		@SumLicenseeWL	= SUM(ISNULL(b.LicenseeWL, 0)),
		@SumComm		= SUM(ISNULL(b.Comm, 0)) ,
		@SumPlayerComm	= SUM(ISNULL(b.PlayerComm, 0)),
		-- EUR
		@SumWinlostEUR		= SUM(ISNULL(b.WinLost		* e.EUR, 0)),
		@SumStakeEUR		= SUM(ISNULL(b.Stake		* e.EUR, 0)),
		@SumLicenseeWLEUR	= SUM(ISNULL(b.LicenseeWL	* e.EUR, 0)),
		@SumCommEUR			= SUM(ISNULL(b.Comm			* e.EUR, 0)),
		@SumPlayerCommEUR	= SUM(ISNULL(b.PlayerComm	* e.EUR, 0)),
		-- USD
		@SumWinlostUSD		= SUM(ISNULL(b.WinLost		* e.USD, 0)),
		@SumStakeUSD		= SUM(ISNULL(b.Stake		* e.USD, 0)),
		@SumLicenseeWLUSD	= SUM(ISNULL(b.LicenseeWL	* e.USD, 0)),
		@SumCommUSD			= SUM(ISNULL(b.Comm			* e.USD, 0)),
		@SumPlayerCommUSD	= SUM(ISNULL(b.PlayerComm	* e.USD, 0)),
		-- GBP
		@SumWinlostGBP		= SUM(ISNULL(b.WinLost		* e.GBP, 0)),
		@SumStakeGBP		= SUM(ISNULL(b.Stake		* e.GBP, 0)),
		@SumLicenseeWLGBP	= SUM(ISNULL(b.LicenseeWL	* e.GBP, 0)),
		@SumCommGBP			= SUM(ISNULL(b.Comm			* e.GBP, 0)),
		@SumPlayerCommGBP	= SUM(ISNULL(b.PlayerComm	* e.GBP, 0))
	FROM #DataTmp AS b
		INNER JOIN #TempExchange AS e ON e.exchangeid = b.currency

	SELECT A.*
	FROM
		(
			SELECT
				ROW_NUMBER() OVER(ORDER BY b.username) AS RowNum,
				151 AS SportType,
				b.*,
				-- EUR
				b.Stake			* e.EUR AS StakeEUR,
				b.WinLost		* e.EUR AS WinLostEUR,
				b.LicenseeWL	* e.EUR AS LicenseeWLEUR,
				b.Comm			* e.EUR AS CommEUR,
				b.PlayerComm	* e.EUR AS PlayerCommEUR,
				-- USD
				b.Stake			* e.USD AS StakeUSD,
				b.WinLost		* e.USD AS WinLostUSD,
				b.LicenseeWL	* e.USD AS LicenseeWLUSD,
				b.Comm			* e.USD AS CommUSD,
				b.PlayerComm	* e.USD AS PlayerCommUSD,
				-- GBP
				b.Stake			* e.GBP AS StakeGBP,
				b.WinLost		* e.GBP AS WinLostGBP,
				b.LicenseeWL	* e.GBP AS LicenseeWLGBP,
				b.Comm			* e.GBP AS CommGBP,
				b.PlayerComm	* e.GBP AS PlayerCommGBP
			FROM #DataTmp AS b
				INNER JOIN #TempExchange AS e ON e.exchangeid = b.currency
		) A
	WHERE A.RowNum BETWEEN @RowStart AND @RowEnd

	-- Get sub tickets
	DECLARE @BettransDetail TABLE(
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

	IF EXISTS (SELECT 1 FROM #DataTmp)
	BEGIN
		IF @date > @MoveBetsDay
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
				INNER JOIN #DataTmp AS b ON bm.refno = b.transid AND bm.custid = b.CustId
				INNER JOIN #TempExchange AS e ON e.ExchangeDate = b.winlostdate AND e.exchangeid = b.currency
				INNER JOIN @SportBettype AS sbt ON sbt.Bettype = bm.bettype
		END
		ELSE
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
			FROM dbo.bettransm14 AS bm WITH (NOLOCK)
				INNER JOIN #DataTmp AS b ON bm.refno = b.transid AND bm.custid = b.CustId
				INNER JOIN #TempExchange AS e ON e.ExchangeDate = b.winlostdate AND e.exchangeid = b.currency
				INNER JOIN @SportBettype AS sbt ON sbt.Bettype = bm.bettype
		END
	END

	SELECT * FROM @BettransDetail
	ORDER BY RefNo, Bettype

	DROP TABLE #DataTmp
	DROP TABLE #TempExchange
	DROP TABLE #currency
END



GO
GRANT EXECUTE ON [dbo].[Lrf_BetList_SelWinlostRacing] TO [bodbLicenseeNet] AS [dbo]
GO
GRANT VIEW DEFINITION ON [dbo].[Lrf_BetList_SelWinlostRacing] TO [vnteam] AS [dbo]