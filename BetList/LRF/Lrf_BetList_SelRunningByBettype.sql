USE [bodb02]
GO

SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO

ALTER PROCEDURE [dbo].[Lrf_BetList_SelRunningByBettype]
	@LicenseeId		INT,
	@UserId			INT,
	@CurrencyId		INT				= 0,
	@LicenseeType	VARCHAR(100)	= NULL,
	@BetType		INT,
	@Langkey		VARCHAR(10)		= 'en-US',
	@PageSize		INT				= 1000,
	@PageIndex		INT				= 1,
	@TotalRows		INT				= 0 OUTPUT
AS

/*
	Created: Henry@20101209
	Task : Betlist
	DB: DBEXT.bodb02
	Original:[Age_BetList_SelRunningByBettype_Ag]
	Revisions:
		- 20110216@Jacob: Add column nickname IN the result SET
		- 20110303@Henry: suppport based currency
		- 20110408@Amy: Change function to get Odds value AND odds type
		- 20110516@@Henry: change bettype to new range
		- 20110630@Henry: add column discount
		- 20110714@Henry: remove column apositiontaking
		- 20110729@Henry: offer 3 new bettypes for Number Game + Combination Mixed Parlay + get status waiting for MP
		- 20110819@Henry: exclude BA tickets
		- 20110918@Viet: temporary hard-code to fix @bettype=430 case
		- 20110922@Henry: remove @bettype = 430 + add column betid for system parlay
		- 20111122@Henry: Compare Checktime and CURRENT_TIMESTAMP to show waiting or running status
		- 20111212@Jim: Edit condition bettype<19000
		- 20111229@Jim: change the way to get odds/oddstype/betteam to web dev
		- 20120214@Jim: change to use  table ExchangeDaily by use function Lrf_f_GetExchangeDaily  	
		- 20120319@Henry: show main transid for sub-ticket of system parlay
		- 20120706@Jim: get sporttype for Outright 
		- 20120726@Jim: add playercomm value 
		- 20120817@Henry: add live casino
		- 20121004@Jim: replace @currencyname input param by @currencyID
		- 20130514@Jim: Restrict permission of Licensee Users by currency
		- 20140925@Jim: restrict Virtual Horse Racing bettype (hot fix  #22012)
		- 20141110@Winnie: Change from LicenseeCust table to [f_SelLicenseeCust] function
		- 20150124@Winnie: Add base currency GBP 
		- 20150414@Jim: support betradar
		- 20151203@Kos: Change odds, modds data type from SMALLMONEY to MONEY [Redmine: #48660]
		- 20161004@Kos: Remove Live Casino code [Redmine: #65045]
*/ 

BEGIN
	SET NOCOUNT ON

	CREATE TABLE #Data (
		CustId			INT,
		SportType		INT,
		Username		NVARCHAR(50),
		BetType			SMALLINT,
		TransId			BIGINT,
		BetId			BIGINT,
		RefNo			BIGINT,
		MatchCode		VARCHAR(50),
		HomeId			INT,
		AwayId			INT,
		Hdp1			SMALLMONEY,
		Hdp2			SMALLMONEY,
		Odds			MONEY,
		MOdds			MONEY,
		Status			NVARCHAR(50),
		Stake			MONEY, 
		Actual_Stake	MONEY,
		TransDate		DATETIME,
		BetTeam			VARCHAR(50),
		LiveHomeScore	SMALLINT,
		LiveAwayScore	SMALLINT,
		LiveIndicator	INT,
		Discount		DECIMAL(9,8),
		LeagueId		INT,
		Ip				NVARCHAR(30),
		IsNeutral		BIT,
		OddsType		TINYINT,
		WinLostDate		DATETIME,
		Currency		SMALLINT,
		StatusId		INT,
		PlayerComm		MONEY ,
		ShowTime		NVARCHAR(50), -- table - shoe - hand of Live Casino
		BetCheck		NVARCHAR(50)
	)

	SELECT currencyID,
		LicenseeID
	INTO #currency
	FROM dbo.Lrf_f_GetCurrencybyUser(@licenseeID, @userID, 1)-- System is default=1 (LRF)
	WHERE @CurrencyId = 0
		OR (@CurrencyId <> 0 AND CurrencyID = @CurrencyId)

	DECLARE @TempAg AS TABLE (custid INT)

	INSERT INTO @TempAg (custid)
	SELECT DISTINCT CustID
	FROM bodb_Licensee.dbo.[f_SelLicenseeCust](0) lc
		INNER JOIN #currency c ON lc.LicenseeID = c.LicenseeID AND lc.Currency = c.CurrencyID
	WHERE [Description] = COALESCE(@LicenseeType, [Description])

	IF @bettype IN (9, 29)
	BEGIN
		INSERT INTO #Data
		SELECT
			b.custid,
			0 AS sporttype,
			b.username,
			b.bettype,
			CASE
				WHEN bettype <> 29 THEN b.transid
				ELSE CASE WHEN ISNULL(b.betid, 0) = 0 THEN b.transid ELSE betid END
			END AS transid,
			ISNULL(b.betid, 0),
			b.refno,
			'' AS MatchCode,
			0 AS homeID,
			0 AS awayID,
			0 AS hdp1,
			0 AS hdp2,
			b.odds,
			b.modds,
			b.status,
			b.stake,
			b.actual_stake,
			b.transdate,
			b.betteam,
			0 AS livehomescore,
			0 AS liveawayscore,
			0 AS liveindicator,
			b.discount,
			0 AS LeagueID,
			b.ip,
			CONVERT(BIT,0) AS IsNeutral,
			0 AS oddstype,
			b.winlostdate,
			b.currency,
			b.statusid,
			b.playercomm,
			'' AS ShowTime,
			'' AS BetCheck
		FROM dbo.bettrans AS b WITH (NOLOCK)
		WHERE
			b.Recommend IN (SELECT custid FROM @TempAg)
			AND ((@CurrencyID = 0 AND b.currency IN (SELECT currencyId FROM #currency))
				OR (@CurrencyID <> 0 AND b.Currency = @CurrencyID))
			AND b.bettype = @bettype
			AND b.matchid = @bettype
			AND b.statusID IN (0, 1)
			AND b.ruben = 0
		ORDER BY
			b.status,
			b.transid
	END
	ELSE IF @bettype = 10 -- Outright
	BEGIN
		INSERT INTO #Data
		SELECT
			b.custid,
			l.sporttype,
			b.username,
			b.bettype,
			b.transid,
			ISNULL(b.betid,0),
			b.refno,
			m.matchcode,
			m.teamid AS homeID,
			0 AS awayID,
			CONVERT(FLOAT, b.hdp1) AS hdp1, 
			CONVERT(FLOAT, b.hdp2) AS hdp2, 
			b.odds,
			b.modds,
			b.status,
			b.stake,
			b.actual_stake,
			b.transdate,
			b.betteam,
			b.livehomescore,
			b.liveawayscore,
			b.liveindicator,
			b.discount,
			m.leagueid,
			b.ip,
			CONVERT(BIT,0) AS IsNeutral,
			0 AS oddstype,
			b.winlostdate,
			b.currency,
			b.statusid,
			b.playercomm,
			'' AS ShowTime,
			'' AS BetCheck
		FROM
			dbo.bettrans AS b WITH (NOLOCK)
			INNER JOIN dbo.outright AS m WITH (NOLOCK) ON  b.matchid = m.orid
			INNER JOIN dbo.league AS l WITH (NOLOCK) ON m.leagueID = l.leagueID
		WHERE
			b.Recommend IN (SELECT custid FROM @TempAg)
			AND ((@CurrencyID = 0 AND b.currency IN (SELECT currencyId FROM #currency))
				OR (@CurrencyID<>0 AND b.currency = @CurrencyID))
			AND b.bettype = @bettype
			AND b.statusID = 0
		ORDER BY b.status,
			b.transid
	END
	ELSE IF @bettype <= 19000
	BEGIN
		INSERT INTO #Data
		SELECT
			b.custid,
			m.sporttype,
			b.username,
			b.bettype,
			b.transid,
			ISNULL(b.betid, 0),
			b.refno,
			m.matchcode,
			m.homeID,
			m.awayID,
			CONVERT(FLOAT, b.hdp1) AS hdp1,
			CONVERT(FLOAT, b.hdp2) AS hdp2,
			b.odds,
			b.modds,
			CASE
				WHEN b.status = 'running' AND ISNULL(b.SecAcceptFlag, 0) = 1 AND ISNULL(b.checktime, CURRENT_TIMESTAMP) > CURRENT_TIMESTAMP THEN 'waiting'  
				ELSE b.status
			END AS status,
			b.stake,
			b.actual_stake,
			b.transdate,
			b.betteam,
			b.livehomescore,
			b.liveawayscore,
			b.liveindicator,
			b.discount,
			m.leagueid,
			b.ip,
			ISNULL(m.isNeutral, CONVERT(BIT,0)) AS IsNeutral,
			b.oddstype,
			b.winlostdate,
			b.currency,
			b.statusid,
			b.playercomm,
			ISNULL(m.showtime,'') AS showtime,
			b.betcheck
 		FROM dbo.bettrans AS b WITH (NOLOCK)
			INNER JOIN dbo.match AS m WITH (NOLOCK) ON b.matchid = m.matchid
		WHERE b.Recommend IN (SELECT custid FROM @TempAg)
			AND ((@CurrencyID = 0 AND b.currency IN (SELECT currencyId FROM #currency))
				OR (@CurrencyID <> 0 AND b.currency = @CurrencyID))
			AND b.bettype = @bettype
			AND b.statusID IN (0, 1)
			AND b.bettype NOT IN (SELECT bettype FROM dbo.f_VSHorseRacingByBettype())
		ORDER BY b.status,
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
				ROW_NUMBER() OVER(ORDER BY b.transid) AS RowNum,
				SUBSTRING(c.username2, CHARINDEX('$', c.username2) + 1, LEN(c.username2) - CHARINDEX('$',c.username2)) AS Nickname,
				b.*,
				b.Stake * e.USD AS StakeUSD,
				b.Stake * e.EUR AS StakeEUR,
				b.Stake * e.GBP AS StakeGBP,
				b.Actual_Stake * e.USD AS Actual_StakeUSD,
				b.Actual_Stake * e.EUR AS Actual_StakeEUR,
				b.Actual_Stake * e.GBP AS Actual_StakeGBP,
				b.PlayerComm * e.USD AS PlayerCommUSD,
				b.PlayerComm * e.EUR AS PlayerCommEUR,
				b.PlayerComm * e.GBP AS PlayerCommGBP
			FROM
				#Data AS b
				INNER JOIN dbo.customer AS c WITH(NOLOCK) ON c.custid = b.custid
				INNER JOIN (SELECT * FROM Lrf_f_GetExchangeDaily(@Today, @Today)) e ON e.exchangeid = b.currency
		) A
	WHERE A.RowNum BETWEEN @RowStart AND @RowEnd

	DROP TABLE #currency
	DROP TABLE #Data
END


GO
GRANT EXECUTE ON [dbo].[Lrf_BetList_SelRunningByBettype] TO [bodbLicenseeNet]
GO
GRANT VIEW DEFINITION ON [dbo].[Lrf_BetList_SelRunningByBettype] TO [vnteam]