USE [bodb02]
GO

SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO

ALTER PROCEDURE [dbo].[Lrf_BetList_SelRunningByBettypeMatch]
	@MatchId		INT,
	@LicenseeId		INT,
	@CurrencyId		INT				= 0,
	@UserId			INT,
	@LicenseeType	VARCHAR(100)	= NULL,
	@BetType		INT,
	@LangKey		VARCHAR(10)		= 'en-US',
	@BetTeam		VARCHAR(20)		= NULL,
	@LiveIndicator	INT				= -1,
	@PageSize		INT				= 1000,
	@PageIndex		INT				= 1,
	@TotalRows		INT				= 0 OUTPUT
AS

/*
	Created: Henry@20101209
	Task: Betlist
	DB: DBEXT.bodb02
	Original: [Age_BetList_SelRunningByBettypeMatch_Ag]
	Revisions:
		- 20110216@Jacob: Add column nickname IN the result SET
		- 20110303@Henry: suppport based currency
		- 20110408@Amy: Change function to get Odds value AND odds type
		- 20110513@Henry: change bettype to new range
		- 20110630@Henry: add column discount
		- 20110714@Henry: remove apositiontaking
		- 20110729@Henry: offer 3 new bettypes for Number Game
		- 20110819@Henry: exclude BA tickets
		- 20111122@Henry: Compare Checktime and CURRENT_TIMESTAMP to show waiting or running status
		- 20111212@Jim: change condition bettype<19000
		- 20111229@Jim: change the way to get odds/oddstype/betteam to web dev
		- 20120214@Jim: change to use  table ExchangeDaily by use function Lrf_f_GetExchangeDaily
		- 20120706@Jim: get sporttype for Outright 
		- 20120726@Jim: add playercomm value 
		- 20120817@Henry: add live casino
		- 20121004@Jim: replace @currencyname input param by @currencyID
		- 20130411@Jim: support base currency USD
		- 20130514@Jim:Restrict permission of Licensee Users by currency
		- 20140925@Jim: restrict Virtual Horse Racing bettype (hot fix  #22012)
		- 20141111@Winnie: change from LicenseeCust to f_SelLicenseeCust 
		- 20150124@Winnie: Add base currency GBP
		- 20150414@Jim: support betradar 
		- 20150630@Jim: remove BA ticket
		- 20151203@Kos: Change odds, modds data type from SMALLMONEY to MONEY [Redmine: #48660]
		- 20161003@Kos: Remove Live Casino code
*/

BEGIN
	SET NOCOUNT ON

	SELECT currencyID,
		LicenseeID 
	INTO #currency
	FROM dbo.Lrf_f_GetCurrencybyUser(@LicenseeId, @userID, 1)-- System is default=1 (LRF)
	WHERE @CurrencyId = 0
		OR (@CurrencyId <> 0 AND CurrencyID = @CurrencyId)

	DECLARE @TempAg AS TABLE (custid INT)

	INSERT INTO @TempAg (custid)
	SELECT DISTINCT CustID
	FROM bodb_Licensee.dbo.f_SelLicenseeCust(0) lc --WITH ( NOLOCK )
		INNER JOIN #currency AS c ON lc.LicenseeID = c.LicenseeID AND lc.Currency = c.CurrencyID
	WHERE [Description] = COALESCE(@LicenseeType, [Description]) 

	SET @BetTeam = RTRIM(LTRIM(ISNULL(@BetTeam, '')))

	CREATE TABLE #Data (
		CustId			INT,
		SportType		INT,
		Username		NVARCHAR(50),
		BetType			SMALLINT,
		TransId			BIGINT,
		MatchCode		VARCHAR(50),
		Race			VARCHAR(50),
		LeagueId		INT,
		HomeId			INT,
		AwayId			INT,
		Hdp1			SMALLMONEY,
		Hdp2			SMALLMONEY,
		Odds			MONEY,
		Status			NVARCHAR(50),
		Stake			MONEY,
		TransDate		DATETIME,
		BetTeam			VARCHAR(50),
		LiveIndicator	INT,
		LiveHomeScore	SMALLINT,
		LiveAwayScore	SMALLINT,
		Discount		DECIMAL(9,8),
		Ip				NVARCHAR(20),
		IsNeutral		BIT,
		OddsType		TINYINT,
		BetId			BIGINT,
		WinLostDate		DATETIME,
		Currency		SMALLINT,
		PlayerComm		MONEY,
		RefNo			BIGINT,
		ShowTime		NVARCHAR(50), -- table - shoe - hand of Live Casino
		BetCheck		NVARCHAR(50)
	)

	IF @BetType = 10
	BEGIN
		INSERT INTO #Data
		SELECT
			b.custid,
			l.sporttype,
			b.Username,
			b.bettype,
			b.transid,
			m.matchcode,
			m.groupmatch AS Race,
			m.leagueid,
			m.teamid AS HomeID,
			0 AS AwayId,
			0 AS hdp1,
			0 AS hdp2,
			b.odds,
			b.status,
			b.stake,
			b.Transdate,
			'' AS Betteam,
			0 AS Liveindicator,
			0 AS Livehomescore,
			0 AS Liveawayscore,
			b.discount,
			b.ip,
			CONVERT(BIT,0) AS isNeutral,
			0 AS oddstype,
			b.betid,
			b.winlostdate,
			b.currency,
			b.playercomm,
			b.refno,
			'' AS ShowTime,
			'' AS betcheck
		FROM 
			dbo.bettrans AS b WITH (NOLOCK)
			INNER JOIN dbo.outright AS m WITH (NOLOCK) ON b.matchid = m.orid
			INNER JOIN dbo.league AS l WITH (NOLOCK) ON m.leagueid = l.leagueid
		WHERE
			b.matchid = @MatchId
			AND b.bettype = @BetType
			AND ((@CurrencyId = 0 AND b.currency IN (SELECT currencyId FROM #currency))
				OR (@CurrencyId <> 0 AND b.currency = @CurrencyId))
			AND b.recommend IN (SELECT custid FROM @TempAg)
			AND b.statusID = 0
		ORDER BY
			b.status,
			b.transid
	END
	--ELSE IF @bettype<=19000: old condition 
	ELSE IF @BetType <= 19000
	BEGIN
		INSERT INTO #Data
		SELECT
			b.custid,
			m.sporttype,
			b.Username,
			b.bettype,
			b.transid,
			m.matchcode,
			'' AS Race,
			m.leagueid,
			m.homeid,
			m.awayid,
			CONVERT(FLOAT, b.hdp1) AS hdp1,
			CONVERT(FLOAT, b.hdp2) AS hdp2,
			b.odds,
			CASE
				WHEN b.status = 'running' AND ISNULL(b.SecAcceptFlag, 0) = 1 AND ISNULL(b.checktime, CURRENT_TIMESTAMP) > CURRENT_TIMESTAMP THEN 'waiting'
				ELSE b.status
			END AS status,
			b.stake,
			b.transdate,
			b.betteam,
			b.liveindicator,
			b.livehomescore,
			b.liveawayscore,
			b.discount,
			b.ip,
			ISNULL(m.isNeutral, CONVERT(BIT,0)) AS IsNeutral,
			b.oddstype,
			b.betid,
			b.winlostdate,
			b.currency,
			b.playercomm,
			b.refno,
			ISNULL(m.showtime,'') AS showtime,
			b.betcheck
		FROM 
			dbo.bettrans AS b WITH (NOLOCK) 
			INNER JOIN dbo.match AS m WITH (NOLOCK) ON b.matchid = m.matchid
		WHERE
			b.matchid = @MatchId
			AND b.bettype = @BetType
			AND ((@CurrencyId = 0 AND b.currency IN (SELECT currencyId FROM #currency))
				OR (@CurrencyId <> 0 AND b.currency = @CurrencyId))
			AND b.recommend IN (SELECT custid FROM @TempAg)
			AND b.statusID IN (0, 1)
			AND b.bettype NOT IN (SELECT bettype FROM dbo.f_VSHorseRacingByBettype())
			AND ((@LiveIndicator = -1)
				OR (@LiveIndicator = 0 AND b.Liveindicator = 0)
				OR (@LiveIndicator = 1 AND b.Liveindicator = 1))
			AND ((@BetTeam = '')
				OR (@BetTeam <> '' AND b.betteam = @BetTeam))
			AND b.tpositiontaking <> 0
		ORDER BY
			b.status,
			b.transid
	END

	DECLARE @RowStart INT,
		@RowEnd INT

	SELECT @PageIndex = @PageIndex - 1,
		@RowStart = @PageSize * @PageIndex + 1,
		@RowEnd = @RowStart + @PageSize - 1

	DECLARE @Today SMALLDATETIME

	SET @Today = CONVERT(VARCHAR(10), CURRENT_TIMESTAMP, 120)

	IF @TotalRows = 0
	BEGIN
		SELECT @TotalRows = COUNT(transid)
		FROM #Data
	END

	SELECT A.* 
	FROM
		(
			SELECT
				ROW_NUMBER() OVER(ORDER BY b.status, b.transid) AS RowNum,
				SUBSTRING(c.username2, CHARINDEX('$',c.username2) + 1, LEN(c.username2) - CHARINDEX('$', c.username2)) AS Nickname,
				b.*,
				b.Stake * e.USD AS StakeUSD,
				b.Stake * e.EUR AS StakeEUR,
				b.Stake * e.GBP AS StakeGBP,
				b.PlayerComm * e.USD AS PlayerCommUSD,
				b.PlayerComm * e.EUR AS PlayerCommEUR,
				b.PlayerComm * e.GBP AS PlayerCommGBP
			FROM #Data AS b
				INNER JOIN dbo.customer AS c WITH(NOLOCK) ON c.custid = b.custid 
				INNER JOIN (SELECT * FROM Lrf_f_GetExchangeDaily(@Today, @Today))e ON e.exchangeid = b.currency
		) A
	WHERE A.RowNum BETWEEN @RowStart AND @RowEnd

	DROP TABLE #Currency
	DROP TABLE #Data
END

GO
