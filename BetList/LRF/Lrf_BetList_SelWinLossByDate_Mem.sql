USE [bodb02]
GO
/****** Object:  StoredProcedure [dbo].[Lrf_BetList_SelWinLossByDate_Mem]    Script Date: 9/24/2015 4:49:37 PM ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
ALTER PROCEDURE [dbo].[Lrf_BetList_SelWinLossByDate_Mem]
	@LicenseeId			INT,
	@UserId				INT,
	@CustId				INT,
	@CurrencyId			INT				= 0,
	@FromDate			SMALLDATETIME,
	@ToDate				SMALLDATETIME,
	@LangKey			VARCHAR(20)		= 'en-US',
	@MoveBetsDay		SMALLDATETIME,
	@BalanceUpDay		SMALLDATETIME,
	@PageSize			INT				= 1000,
	@PageIndex			INT				= 1,
	@TotalRows			INT				= 0 OUTPUT,
	@SumWinlost			MONEY			= 0 OUTPUT,
	@SumBetEffective	MONEY			= 0 OUTPUT,
	@SumLicenseeWL		MONEY			= 0 OUTPUT,
	@SumComm			MONEY			= 0 OUTPUT,
	@SumPlayerComm		MONEY			= 0 OUTPUT,
	@SumWinlostUSD		MONEY			= 0 OUTPUT,
	@SumBetEffectiveUSD	MONEY			= 0 OUTPUT,
	@SumLicenseeWLUSD 	MONEY			= 0 OUTPUT,
	@SumCommUSD			MONEY			= 0 OUTPUT,
	@SumPlayerCommUSD	MONEY			= 0 OUTPUT,
	@SumWinlostEUR		MONEY			= 0 OUTPUT,
	@SumBetEffectiveEUR	MONEY			= 0 OUTPUT,
	@SumLicenseeWLEUR	MONEY			= 0 OUTPUT,
	@SumCommEUR			MONEY			= 0 OUTPUT,
	@SumPlayerCommEUR	MONEY			= 0 OUTPUT,
	@SumWinlostGBP		MONEY			= 0 OUTPUT,
	@SumBetEffectiveGBP	MONEY			= 0 OUTPUT,
	@SumLicenseeWLGBP	MONEY			= 0 OUTPUT,
	@SumCommGBP			MONEY			= 0 OUTPUT,
	@SumPlayerCommGBP	MONEY			= 0 OUTPUT,
	@ShowSB				BIT				= 0,
	@ShowRB				BIT				= 0,
	@ShowNG				BIT				= 0,
	@ShowBA				BIT				= 0,
	@ShowLC				BIT				= 0,
	@ShowVS				BIT				= 0,
	@ShowCS				BIT				= 0,	-- RNG Casino
	@ShowKN				BIT				= 0,	-- Keno
	@ShowMGCLC			BIT				= 0,	-- Microgaming Live Casino
	@ShowMGCRNG			BIT				= 0,	-- Microgaming RNG Casino
	@ShowAGC			BIT				= 0,	-- AG Casino Single Wallet
	@ShowAB				BIT				= 0,	-- AllBet
	@ShowVB				BIT				= 0,	-- Voidbridge
	@ShowFW				BIT				= 0,	-- Fishing World
	@ShowBT				BIT				= 0		-- Bet Trade
AS

/*
	Created: 20101209@Henry
	Task: Bet List Win-loss By Date
	DB: DBACC.bodb02
	Original: [Age_BetList_SelWinLossByDate_Mem]

	Revisions:
		- 20110214@Jacob: Add column discount in the result SET
		- 20110303@Henry: suppport based currency
		- 20110318@Henry: Change server DB052 to DB06 (support bet list old)
		- 20110408@Amy: Change function to get Odds value AND odds type
						Get data for Number Game
		- 20110513@Henry: change bettype to new range
		- 20110523@Henry: remove @ShowCasino, @ShowP2P, @ShowFI, @ShowBI
		- 20110712@Henry: Add column LicenseeWL
		- 20110729@Henry: offer 3 new bettypes for Number Game + Combination Mixed Parlay
		- 20111208@Jim: change condition bettype<31
		- 20111229@Jim: change the way to get odds/oddstype/betteam to web dev
		- 20120319@Henry: show main transid for sub-ticket of system parlay
		- 20120614@Jim: optimize code
		- 20120711@Jim: get value for hdp1, hdp2
		- 20120726@Jim: add playercomm value
		- 20120817@Jim: add live casino
		- 20120913@Jim: add virtual sport
		- 20130123@Daniel: Change link server alias
		- 20130225@Jim: support RNG Casino, Bingo
		- 20130514@Jim:Restrict permission of Licensee Users by currency
		- 20130716@Jim: update matchid for RNG Casino and Bingo
		- 20130903@Jim: support Virtual Horse Racing
		- 20131101@Victor: enhance performance
		- 20140326@Jim: offer Keno
		- 20140630@Hannah: offer BetRadar and Sporting Solution
		- 20140819@Jim: add more output @SumBetEffective
		- 20140908@Jim: restrict Virtual Horse Racing bettype (hot fix  #22012)
		- 20141128@Jim: add more input param @CurrencyID
		- 20150128@Winnie: Add base currency GBP
		- 20150406@Winnie: Apply sporttype, bettype matrix and add 60 bettypes betradar 
		- 20150406@Winnie: fix bug
		- 20150604@Edward: Support Microgaming
		- 20150608@Edward: Support Bet Trade
		- 20150729@Edward: Return betcheck for Microgaming
		- 20150828@Edward: Fixed Odds value of ticket 901, 902 is displayed incorrectly
		- 20150915@Kos: Support Microgaming RNG Game
		- 20150922@Kos: Support AG Casino
		- 20151029@Kos: Change ProductId/SportType of Microgaming RNG Game
		- 20151203@Kos: Change odds, modds data type from SMALLMONEY to MONEY [Redmine: #48660]
		- 20151224@Jim: Fix bug [Redmine: #49885]
		- 20151225@Kos: Support RNG Casino Single Wallet [Redmine: #48958]
		- 20160201@Kos: Support PH All In One 1.2 [#Redmine: 50897]
		- 20160216@Kos: Support yesterday running ticket [Redmine: #52277]
		- 20160316@Kos: Exclude Void/Reject tickets [Redmine: #43921]
		- 20160405@Kos: Support Voidbridge [#Redmine: 54925]
		- 20160414@Kos: Support Combo Parlay [#Redmine: 55282]
		- 20160714@Kos: Change to use inline function for SportBettypeMatrix
		- 20160726@Kos: Support AllBet [#Redmine: 61066]
		- 20160801@Kos: Exclude bet type 904 [#Redmine: 58978]
		- 20161006@Kos: Add product bet type range for sub tickets [Redmine: #65045]
		- 20161114@Kos: Support Fishing World [#Redmine: 66737]
*/

BEGIN
	SET NOCOUNT ON

	----Get Sport Bettype Matrix------
	DECLARE @SportBettype TABLE(ProductID TINYINT, Bettype SMALLINT, EventType TINYINT, SubProduct VARCHAR(500))

	DECLARE @IsTest BIT = 0

	SELECT @IsTest = dbo.f_CheckSPVersion(@@PROCID)

	INSERT INTO @SportBettype
	SELECT ProductID, BetType, EventType, SubProduct
	FROM dbo.f_SportBettypeMatrix_Sel (0, 0, 0, 2, '', '', @IsTest)
	WHERE ProductID <= 6 OR ProductID IN (8, 11, 13, 17, 21, 22, 24)

	DELETE @SportBettype
	WHERE ProductID = 1 AND Bettype = 904

	IF @ShowBT = 0
	BEGIN
		DELETE @SportBettype
		WHERE ProductID = 1 AND Bettype IN (901, 902, 903)
	END

	DELETE FROM @SportBettype
	WHERE (ProductID	= CASE WHEN @ShowSB	= 0 AND @ShowBA = 0 THEN 1 END AND Bettype NOT IN (901, 902, 903))
		OR ProductID	= CASE WHEN @ShowRB	= 0		THEN 2 END
		OR ProductID	= CASE WHEN @ShowNG	= 0		THEN 3 END
		OR ProductID	= CASE WHEN @ShowLC	= 0		THEN 4 END
		OR ProductID	= CASE WHEN @ShowVS	= 0		THEN 5 END
		OR ProductID	= CASE WHEN @ShowCS	= 0		THEN 6 END
		OR ProductID	= CASE WHEN @ShowKN	= 0		THEN 8 END
		OR ProductID	= CASE WHEN @ShowAGC = 0	THEN 11 END
		OR ProductID	= CASE WHEN @ShowMGCLC = 0	THEN 13 END
		OR ProductID	= CASE WHEN @ShowMGCRNG = 0	THEN 17 END
		OR ProductID	= CASE WHEN @ShowAB	 = 0	THEN 21 END
		OR ProductID	= CASE WHEN @ShowVB	 = 0	THEN 22 END
		OR ProductID	= CASE WHEN @ShowFW	 = 0	THEN 24 END

	DECLARE @UserName		NVARCHAR(20)
		, @Recommend		INT
		, @BetEffectiveDate SMALLDATETIME

	SELECT CurrencyID
		, LicenseeID
	INTO #Currency
	FROM DBLIC.bodb_licensee.dbo.CurrencyUser WITH (NOLOCK)
	WHERE usrID = @userID 
		AND LicenseeID = @LicenseeID 
		AND SystemID = 1
		AND isActive = 1

	SELECT @BetEffectiveDate = '2014-09-01'

	SELECT @UserName = UserName,
		@Recommend = Recommend
	FROM dbo.custinfo AS c WITH (NOLOCK)
		INNER JOIN #Currency AS cy ON c.Currency = cy.CurrencyID
	WHERE CustID = @CustID
	----------------------------------------
	DROP TABLE #currency
	-----------------------------------------
	CREATE TABLE #BetListByDateMem (
		SportType		SMALLINT,
		Username		NVARCHAR(20),
		TransId			BIGINT,
		BetId			BIGINT,
		BetType			SMALLINT,
		Hdp1			SMALLMONEY,
		Hdp2			SMALLMONEY,
		OddsType		TINYINT,
		Odds			MONEY,
		Modds			MONEY,
		Stake			MONEY,
		Actual_Stake	MONEY,
		BetTeam			NVARCHAR(20),
		Status			NVARCHAR(10),
		RefNo			BIGINT,
		TransDate		DATETIME,
		WinLostDate		DATETIME,
		WinLost			MONEY,
		BetEffective	MONEY,
		LicenseeWL		MONEY,
		Comm			MONEY,
		PlayerComm		MONEY,
		LiveIndicator	BIT,
		LiveHomeScore	SMALLINT,
		LiveAwayScore	SMALLINT,
		Ip				NVARCHAR(15),
		LeagueId		INT,
		MatchId			INT,
		MatchCode		NVARCHAR(50),
		Race			NVARCHAR(20),
		HomeId			INT,
		AwayId			INT,
		BetStatus		NVARCHAR(50),
		IsNeutral		BIT,
		Currency		SMALLINT,
		ShowTime		NVARCHAR(50), -- table - shoe - hand of Live Casino
		BetCheck		NVARCHAR(50),
		TransDesc		NVARCHAR(300)
	)

	CREATE TABLE #TempBetList (
		TransId			BIGINT,
		BetId			BIGINT,
		BetType			INT,
		Hdp1			SMALLMONEY,
		Hdp2			SMALLMONEY,
		OddsType		TINYINT,
		Odds			MONEY,
		Modds			MONEY,
		Stake			MONEY,
		Actual_Stake	MONEY,
		BetTeam			NVARCHAR(20),
		Status			NVARCHAR(10),
		RefNo			BIGINT,
		TransDate		DATETIME,
		WinLostDate		DATETIME,
		WinLost			MONEY,
		BetEffective	MONEY,
		LicenseeWL		MONEY,
		Comm			MONEY,
		PlayerComm 		MONEY,
		LiveIndicator	BIT,
		LiveHomeScore	SMALLINT,
		LiveAwayScore	SMALLINT,
		Ip				NVARCHAR(50),
		Currency		INT,
		MatchId			INT,
		BetCheck		NVARCHAR(50),
		TransDesc		NVARCHAR(300)
	)

	DECLARE @TempFromDate DATETIME
	DECLARE @TempToDate DATETIME

	DECLARE @Yesterday SMALLDATETIME
	DECLARE @Today DATETIME

	SET @Yesterday = DATEADD(DAY, DATEDIFF(DAY, 1, GETDATE()), 0)
	SET @Today = DATEADD(DAY, DATEDIFF(DAY, 0, GETDATE()), 0)

	IF @Todate > @MoveBetsDay
	BEGIN
		IF @FromDate <= @MoveBetsDay
			SET @TempFromDate =  DATEADD(DAY, 1, @MoveBetsDay)
		ELSE
			SET @TempFromDate = @FromDate

		-- BA tickets
		INSERT INTO #TempBetList
		SELECT
			b.transid,
			ISNULL(b.betid, 0),
			b.bettype,
			b.hdp1,
			b.hdp2,
			b.oddstype,
			b.odds,
			b.modds,
			b.stake,
			b.actual_stake,
			b.betteam,
			b.status,
			b.refno,
			b.Transdate,
			b.winlostdate,
			(b.winlost-actual_stake),
			ABS(b.winlost-actual_stake),
			0 AS LicenseeWL,
			b.comm,
			b.playercomm,
			b.liveindicator,
			b.livehomescore,
			b.liveawayscore,
			b.ip,
			b.currency,
			b.matchid,
			b.betcheck,
			ISNULL(b.transdesc, '') AS transdesc
		FROM
			dbo.bettrans AS b WITH (NOLOCK)
			INNER JOIN DBLIC.bodb_Licensee.dbo.LicenseeBATransaction BA WITH (NOLOCK) ON b.transid = BA.transid
		WHERE
			b.winlostdate BETWEEN @TempFromDate AND @todate
			AND b.recommend = @Recommend --to improve performance
			AND b.custid = @custid
			AND b.statusID IN (111, 112, 113)
			AND b.bettype NOT IN (901, 902, 903)

		IF @ShowBA = 1
		BEGIN
			-- Sportsbook
			INSERT INTO #BetListByDateMem
			SELECT
				m.sporttype,
				@Username,
				b.TransId,
				b.BetId,
				b.BetType,
				b.Hdp1,
				b.Hdp2,
				b.OddsType,
				b.Odds,
				b.Modds,
				b.Stake,
				b.Actual_Stake,
				b.BetTeam,
				b.Status,
				b.RefNo,
				b.TransDate,
				b.WinLostDate,
				b.WinLost,
				b.BetEffective,
				b.LicenseeWL,
				b.Comm,
				b.PlayerComm,
				b.LiveIndicator,
				b.LiveHomeScore,
				b.LiveAwayScore,
				b.Ip,
				m.leagueid,
				m.matchid,
				m.matchcode,
				'' AS Race,
				m.homeid,
				m.awayid,
				m.betstatus,
				ISNULL(m.isNeutral, CONVERT(BIT,0)) AS IsNeutral,
				b.Currency,
				'' AS ShowTime,
				b.BetCheck,
				b.TransDesc
			FROM
				#TempBetList AS b
				INNER JOIN dbo.match AS m WITH (NOLOCK) ON b.matchid = m.matchid
				INNER JOIN @SportBettype AS sbt ON b.Bettype = sbt.Bettype
			WHERE sbt.ProductID = 1 AND sbt.EventType = 1

			-- Outright
			INSERT INTO #BetListByDateMem
			SELECT
				l.sporttype,
				@Username,
				b.TransID,
				b.BetID,
				b.Bettype,
				CONVERT(FLOAT, b.hdp1) AS hdp1,
				CONVERT(FLOAT, b.hdp2) AS hdp2,
				0 AS OddsType,
				b.Odds,
				b.modds,
				b.stake,
				b.actual_stake,
				'' AS Betteam,
				b.Status,
				b.refno,
				b.Transdate,
				b.winlostdate,
				b.winlost,
				b.BetEffective,
				b.LicenseeWL,
				b.comm,
				b.playercomm,
				0 AS LiveIndicator,
				b.LiveHomescore,
				b.LiveAwayscore,
				b.IP,
				m.LeagueID,
				m.OrId, --MatchID
				m.MatchCode,
				m.GroupMatch,--Race
				m.TeamID, --HomeID
				0, --AwayID
				0, --Betstatus
				CONVERT(BIT,0) AS IsNeutral,
				b.currency,
				'' AS ShowTime,
				'' AS betcheck,
				'' AS transdesc
			FROM
				#TempBetList AS b
				INNER JOIN dbo.outright AS m WITH (NOLOCK) ON b.matchid = m.orid
				INNER JOIN dbo.league AS l WITH (NOLOCK) ON m.leagueID = l.leagueID
				INNER JOIN @SportBettype AS sbt ON b.Bettype = sbt.Bettype
			WHERE sbt.ProductID = 1 AND sbt.EventType = 2

			-- Mix Parlay + Combination Mixed Parlay
			INSERT INTO #BetListByDateMem
			SELECT
				0, --Sporttype
				@Username,
				b.TransID,
				b.BetID,
				b.bettype,
				b.hdp1,
				b.hdp2,
				0 AS OddsType,
				b.Odds,
				b.modds,
				b.stake,
				b.actual_stake,
				b.betteam,
				b.Status,
				b.refno,
				b.Transdate,
				b.winlostdate,
				b.winlost,
				b.BetEffective,
				b.LicenseeWL,
				b.comm,
				b.playercomm,
				b.Liveindicator,
				b.Livehomescore,
				b.Liveawayscore,
				b.IP,
				0, --LeagueID
				0, --MatchID
				'',--MatchCode
				'',--Race
				0, --HomeID
				0, --AwayID
				0, --Betstatus
				CONVERT(BIT,0) AS IsNeutral,
				b.currency,
				'' AS ShowTime,
				ISNULL(b.betcheck, '') AS BetCheck,
				'' AS transdesc
			FROM #TempBetList AS b
				INNER JOIN @SportBettype AS sbt ON b.Bettype = sbt.Bettype
			WHERE
				sbt.ProductID = 1 
				AND sbt.EventType = 0 
				AND b.matchid IN (9, 29)
		END

		-- Sportsbook
		IF @ShowSB = 1
		BEGIN
			INSERT INTO #BetListByDateMem
			SELECT
				m.Sporttype,
				@Username,
				b.transid,
				ISNULL(b.betid,0),
				b.Bettype,
				b.hdp1,
				b.hdp2,
				b.OddsType,
				b.Odds,
				b.modds,
				b.stake,
				b.actual_stake,
				b.betteam,
				b.status,
				b.refno,
				b.transdate,
				b.winlostdate,
				(b.winlost-actual_stake),
				ABS(b.winlost-actual_stake),
				- (b.winlost-b.actual_stake) AS LicenseeWL,
				b.comm,
				b.playercomm,
				b.liveindicator,
				b.livehomescore,
				b.liveawayscore,
				b.ip,
				m.leagueid,
				m.matchid,
				m.matchcode,
				'' AS Race,
				m.homeid,
				m.awayid,
				m.Betstatus,
				ISNULL(m.isNeutral, CONVERT(BIT,0)) AS IsNeutral,
				b.currency,
				'' AS ShowTime,
				b.betcheck,
				ISNULL(b.transdesc, '') AS transdesc
			FROM
				dbo.bettrans AS b WITH (NOLOCK)
				INNER JOIN dbo.match AS m WITH (NOLOCK) ON b.matchid = m.matchid
				INNER JOIN @SportBettype AS sbt ON b.Bettype = sbt.Bettype
			WHERE
				b.winlostdate BETWEEN @TempFromDate AND @todate
				AND b.recommend = @Recommend --to improve performance
				AND b.matchid > 0
				AND b.custid = @custid
				AND sbt.ProductID = 1
				AND sbt.EventType = 1
				AND b.bettype NOT IN (901, 902, 903) 
				AND b.statusID IN (111, 112, 113)
				AND b.transid NOT IN (SELECT Transid FROM #TempBetList) 

			-- Outright
			INSERT INTO #BetListByDateMem
			SELECT
				l.sporttype,
				@Username,
				b.TransID,
				ISNULL(b.BetID,0),
				b.Bettype,
				CONVERT(FLOAT, b.hdp1) AS hdp1,
				CONVERT(FLOAT, b.hdp2) AS hdp2,
				0 AS OddsType,
				b.Odds,
				b.modds,
				b.stake,
				b.actual_stake,
				'' AS Betteam,
				b.Status,
				b.refno,
				b.Transdate,
				b.winlostdate,
				(b.winlost-actual_stake),
				ABS(b.winlost-actual_stake),
				- (b.winlost-b.actual_stake) AS LicenseeWL,
				b.comm,
				b.playercomm,
				0 AS LiveIndicator,
				b.LiveHomescore,
				b.LiveAwayscore,
				b.IP,
				m.LeagueID,
				m.OrId,	--MatchID
				m.MatchCode,
				m.GroupMatch,--Race
				m.TeamID, --HomeID
				0, --AwayID
				0, --Betstatus
				CONVERT(BIT,0) AS IsNeutral,
				b.currency,
				'' AS ShowTime,
				'' AS betcheck,
				'' AS transdesc
			FROM
				dbo.bettrans AS b WITH (NOLOCK)
				INNER JOIN dbo.outright AS m WITH (NOLOCK) ON b.matchid = m.orid
				INNER JOIN dbo.league AS l WITH (NOLOCK) ON m.leagueID = l.leagueID
				INNER JOIN @SportBettype AS sbt ON b.Bettype = sbt.Bettype
			WHERE
				b.winlostdate BETWEEN @TempFromDate AND @todate 
				AND b.recommend = @Recommend
				AND b.custid = @custid
				AND sbt.ProductID = 1
				AND sbt.EventType = 2
				AND b.statusID IN (111, 112, 113)
				AND b.transid NOT IN (SELECT Transid FROM #TempBetList) 

			-- Mix Parlay + Combination Mix Parlay
			INSERT INTO #BetListByDateMem
			SELECT
				0, --Sporttype
				@Username,
				b.TransID,
				ISNULL(b.BetID,0),
				b.bettype,
				b.hdp1,
				b.hdp2,
				0 AS OddsType,
				b.Odds,
				b.modds,
				b.stake,
				b.actual_stake,
				b.betteam,
				b.Status,
				b.refno,
				b.Transdate,
				b.winlostdate,
				(b.winlost-actual_stake),
				ABS(b.winlost-actual_stake),
				- (b.winlost-b.actual_stake) AS LicenseeWL,
				b.comm,
				b.playercomm,
				b.liveindicator,
				b.livehomescore,
				b.liveawayscore,
				b.ip,
				0, --LeagueID
				0, --MatchID
				'',--MatchCode
				'',--Race
				0, --HomeID
				0, --AwayID
				0, --Betstatus
				CONVERT(BIT,0) AS IsNeutral,
				b.currency,
				'' AS ShowTime,
				ISNULL(b.betcheck, '') AS BetCheck,
				'' AS transdesc
			FROM
				dbo.bettrans AS b WITH (NOLOCK)
				INNER JOIN @SportBettype AS sbt ON b.Bettype = sbt.Bettype
			WHERE
				b.winlostdate BETWEEN @TempFromDate AND @todate
				AND b.recommend = @Recommend
				AND b.custid = @custid
				AND sbt.ProductID = 1
				AND sbt.EventType = 0
				AND b.matchid IN (9, 29)
				AND b.statusID IN (111, 112, 113)
				AND b.transid NOT IN (SELECT Transid FROM #TempBetList) 
		END

		-- BetTrade
		IF @ShowBT = 1
		BEGIN
			INSERT INTO #BetListByDateMem
			SELECT
				m.sporttype,
				@Username,
				b.transid,
				ISNULL(ob.bettype,0),
				b.bettype,
				b.hdp1,
				b.hdp2,
				b.oddstype,
				ob.Odds,
				b.modds,
				ob.stake,
				b.actual_stake, 
				b.betteam,
				b.status,
				b.refno,
				b.Transdate,
				b.winlostdate,
				(b.winlost-b.actual_stake),
				ABS(b.winlost-b.actual_stake),
				- (b.winlost-b.actual_stake) AS LicenseeWL,
				CASE WHEN b.bettype = 903 THEN b.awinlost ELSE b.comm END AS comm,
				b.playercomm,
				b.liveindicator,
				b.livehomescore,
				b.liveawayscore,
				b.ip,
				m.leagueid,
				m.matchid,
				m.matchcode,
				'' AS Race,
				m.homeid,
				m.awayid,
				m.betstatus,
				ISNULL(m.isNeutral, CONVERT(BIT,0)) AS IsNeutral,
				b.currency,
				'' AS ShowTime,
				b.betcheck,
				'' AS transdesc
			FROM
				dbo.bettrans AS b WITH (NOLOCK)
				INNER JOIN dbo.bettrans AS ob WITH (NOLOCK)	ON b.refno = ob.transid
				INNER JOIN dbo.match AS m WITH (NOLOCK) ON b.matchid = m.matchid
				INNER JOIN @SportBettype AS sbt ON b.Bettype = sbt.Bettype
			WHERE
				b.winlostdate BETWEEN @TempFromDate AND @todate
				AND b.recommend = @Recommend --to improve performance
				AND b.matchid > 0
				AND b.custid = @custid
				AND sbt.ProductID = 1
				AND sbt.EventType = 1
				AND b.bettype IN (901, 902, 903)
				AND b.statusID IN (111, 112, 113)
		END

		-- Horse Racing
		IF @ShowRB = 1
		BEGIN
			INSERT INTO #BetListByDateMem
			SELECT
				l.sporttype,
				@Username,
				b.TransID,
				ISNULL(b.BetID,0),
				b.Bettype,
				b.hdp1, 
				b.hdp2,
				0 AS OddsType, 
				b.Odds, 
				b.modds,
				b.stake,
				b.actual_stake,
				'' AS Betteam,
				b.Status,
				b.refno,
				b.Transdate,
				b.winlostdate,
				(b.winlost-actual_stake),
				ABS(b.winlost-actual_stake),
				b.awinlost,
				b.comm,
				b.playercomm,
				0 AS LiveIndicator,
				b.LiveHomescore,
				b.LiveAwayscore,
				b.IP,
				m.LeagueID,
				m.OrId,	--MatchID
				m.MatchCode,
				m.GroupMatch,--Race
				m.TeamID, --HomeID
				0, --AwayID
				0, --Betstatus
				CONVERT(BIT,0) AS IsNeutral,
				b.currency,
				'' AS ShowTime,
				'' AS betcheck,
				'' AS transdesc
			FROM
				dbo.bettrans AS b WITH (NOLOCK)
				INNER JOIN dbo.outright AS m WITH (NOLOCK) ON b.matchid = m.orid
				INNER JOIN dbo.league AS l WITH (NOLOCK) ON m.leagueID = l.leagueID
				INNER JOIN @SportBettype AS sbt ON b.Bettype = sbt.Bettype
			WHERE
				b.winlostdate BETWEEN @TempFromDate AND @todate 
				AND b.recommend = @Recommend 
				AND b.custid = @custid
				AND sbt.ProductID = 2
				AND b.statusID IN (111, 112, 113)
		END

		-- Number Game, Live Casino
		IF @ShowNG = 1 OR @ShowLC = 1
		BEGIN
			INSERT INTO #BetListByDateMem
			SELECT
				m.sporttype,
				@Username,
				b.transid,
				ISNULL(b.BetID,0),
				b.bettype,
				CONVERT(FLOAT, b.hdp1) AS hdp1,
				CONVERT(FLOAT, b.hdp2) AS hdp2,
				b.Oddstype,
				b.Odds,
				b.modds,
				b.stake,
				b.actual_stake, 
				b.betteam,
				b.status,
				b.refno,
				b.transdate,
				b.winlostdate,
				(b.winlost-actual_stake),
				ABS(b.winlost-actual_stake),
				- (b.winlost-b.actual_stake) AS LicenseeWL,
				b.comm,
				b.playercomm,
				b.liveindicator,
				b.livehomescore,
				b.liveawayscore,
				b.ip,
				m.leagueid,
				m.matchid,
				m.matchcode,
				'' AS Race,
				m.homeid,
				m.awayid,
				m.Betstatus,
				CONVERT(BIT,0) AS IsNeutral,
				b.currency,
				CASE WHEN sbt.ProductID = 4 THEN ISNULL(m.showtime,'') ELSE '' END AS ShowTime,
				'' AS betcheck,
				'' AS transdesc
			FROM
				dbo.bettrans AS b WITH (NOLOCK)
				INNER JOIN dbo.match AS m WITH (NOLOCK) ON b.matchid = m.matchid
				INNER JOIN @SportBettype AS sbt ON b.Bettype = sbt.Bettype
			WHERE
				b.winlostdate BETWEEN @TempFromDate AND @todate 
				AND b.recommend = @Recommend --to improve performance
				AND b.custid = @CustID 
				AND sbt.ProductID IN (3, 4) 
				AND b.statusID IN (111, 112, 113)
		END

		-- Virtual Sports
		IF @ShowVS = 1
		BEGIN
			INSERT INTO #BetListByDateMem
			SELECT
				m.Sporttype,
				@Username,
				b.transid,
				ISNULL(b.betid,0),
				b.Bettype,
				CONVERT(FLOAT, b.hdp1) AS hdp1,
				CONVERT(FLOAT, b.hdp2) AS hdp2,
				b.Oddstype,
				b.Odds,
				b.modds,
				b.stake,
				b.actual_stake,
				b.betteam,
				b.status,
				b.refno,
				b.transdate,
				b.winlostdate,
				(b.winlost-actual_stake),
				ABS(b.winlost-actual_stake),
				- (b.winlost-b.actual_stake) AS LicenseeWL,
				b.comm,
				b.playercomm,
				b.liveindicator,
				b.livehomescore,
				b.liveawayscore,
				b.ip,
				m.LeagueID,
				m.MatchID,
				m.MatchCode,
				'' AS Race,
				m.HomeID,
				m.AwayID,
				m.Betstatus,
				CONVERT(BIT,0) AS IsNeutral,
				b.currency,
				'' AS ShowTime,
				'' AS betcheck,
				'' AS transdesc
			FROM
				dbo.bettrans AS b WITH (NOLOCK)
				INNER JOIN dbo.match AS m WITH (NOLOCK) ON b.matchid = m.matchid
				INNER JOIN @SportBettype AS sbt ON b.Bettype = sbt.Bettype	
			WHERE
				b.winlostdate BETWEEN @TempFromDate AND @todate
				AND b.recommend = @Recommend --to improve performance
				AND b.custid = @CustID
				AND sbt.ProductID = 5
				AND sbt.EventType = 1
				AND b.statusID IN (111, 112, 113)

			UNION ALL 

			SELECT
				r.Sporttype,
				@Username,
				b.TransID,
				ISNULL(b.BetID,0),
				b.Bettype,
				CONVERT(FLOAT, b.hdp1) AS hdp1,
				CONVERT(FLOAT, b.hdp2) AS hdp2,
				b.Oddstype,
				b.Odds,
				b.modds,
				b.stake,
				b.actual_stake,
				b.betteam,
				b.status,
				b.refno,
				b.Transdate,
				b.winlostdate,
				(b.winlost-actual_stake),
				ABS(b.winlost-actual_stake),
				- (b.winlost-b.actual_stake) AS LicenseeWL,
				b.comm,
				b.playercomm,
				b.Liveindicator,
				b.Livehomescore,
				b.Liveawayscore,
				b.IP,
				r.LeagueID,
				o.EventID matchid,
				CONVERT(VARCHAR(50),o.RacerNum) MatchCode,
				b.oddsid AS Race,
				o.RacerID HomeID,
				0 AwayID,
				r.Betstatus,
				CONVERT(BIT,0) AS IsNeutral,
				b.currency,
				CONVERT(VARCHAR(20),r.EventTime) AS ShowTime,
				'' AS betcheck,
				'' AS transdesc
			FROM
				dbo.bettrans AS b WITH (NOLOCK)
				INNER JOIN dbo.VSOutright AS o WITH (NOLOCK) ON b.oddsid = o.Orid
				INNER JOIN dbo.VSRaceInfo AS r WITH (NOLOCK) ON r.EventID = o.EventID
				INNER JOIN @SportBettype AS sbt ON b.Bettype = sbt.Bettype
			WHERE
				b.winlostdate BETWEEN @TempFromDate AND @todate 
				AND b.recommend = @Recommend --to improve performance
				AND b.custid = @CustID
				AND sbt.ProductID = 5
				AND sbt.EventType = 3
				AND b.statusID IN (111, 112, 113)
		END

		-- RNG Casino, Microgaming Live Casino
		IF @ShowCS = 1 OR @ShowMGCLC = 1
		BEGIN
			INSERT INTO #BetListByDateMem
			SELECT
				CASE
					WHEN sbt.ProductID = 6 THEN 251
					WHEN sbt.ProductID = 13 THEN 203
				END AS Sporttype,
				@Username,
				b.transid,
				ISNULL(b.betid, 0),
				b.bettype,
				CONVERT(FLOAT, b.hdp1) AS hdp1,
				CONVERT(FLOAT, b.hdp2) AS hdp2,
				b.oddstype,
				b.odds,
				b.modds,
				b.stake,
				b.actual_stake,
				CASE
					WHEN sbt.ProductID = 6 THEN b.Betteam
					ELSE ''
				END AS Betteam,
				b.status,
				b.refno,
				b.Transdate,
				b.winlostdate,
				(b.winlost - b.actual_stake) AS Winlost,
				ABS(b.winlost - b.actual_stake) AS BetEffective,
				- (b.winlost - b.actual_stake) AS LicenseeWL,
				b.comm,
				b.playercomm,
				b.Liveindicator,
				b.Livehomescore,
				b.Liveawayscore,
				b.IP,
				0 AS LeagueID,
				CASE
					WHEN sbt.ProductID = 6 THEN b.bettype
					ELSE 0
				END AS MatchID,
				'' AS MatchCode,
				'' AS Race,
				0 AS HomeID,
				0 AS AwayID,
				0 AS Betstatus,
				CONVERT(BIT, 0) AS IsNeutral,
				b.currency,
				'' AS ShowTime,
				CASE
					WHEN sbt.ProductID = 13 THEN b.betcheck
					ELSE ''
				END AS betcheck,
				'' AS transdesc
			FROM
				dbo.bettrans AS b WITH (NOLOCK)
				INNER JOIN @SportBettype AS sbt ON b.Bettype = sbt.Bettype
			WHERE
				b.winlostdate BETWEEN @TempFromDate AND @todate
				AND b.recommend = @Recommend --to improve performance
				AND b.custid = @CustID 
				AND (sbt.ProductID = 13
					OR (sbt.ProductID = 6 AND sbt.SubProduct = ''))
				AND b.statusID IN (111, 112, 113)
		END

		-- Keno
		IF @ShowKN = 1
		BEGIN
			INSERT INTO #BetListByDateMem
			SELECT
				202 AS Sporttype,
				@Username,
				b.TransID,
				ISNULL(b.BetID,0),
				b.Bettype,
				CONVERT(FLOAT, b.hdp1) AS hdp1,
				CONVERT(FLOAT, b.hdp2) AS hdp2,
				b.Oddstype,
				b.Odds,
				b.modds,
				b.stake,
				b.actual_stake,
				ChoiceId betteam,
				b.status,
				b.refno,
				b.Transdate,
				b.winlostdate,
				(b.winlost-actual_stake),
				ABS(b.winlost-actual_stake),
				- (b.winlost-b.actual_stake) AS LicenseeWL,
				b.comm,
				b.playercomm,
				b.Liveindicator,
				b.Livehomescore,
				b.Liveawayscore,
				b.IP,
				0 AS LeagueID,
				GameId AS MatchID,
				'' AS MatchCode,
				'' AS Race,
				0 AS HomeID,
				0 AS AwayID,
				0 AS Betstatus,
				CONVERT(BIT,0) AS IsNeutral,
				b.currency,
				'' AS ShowTime,
				'' AS betcheck,
				'' AS transdesc
			FROM
				dbo.bettrans AS b WITH (NOLOCK)
				CROSS APPLY dbo.f_ParseTransDesc(b.transdesc, b.bettype)
				INNER JOIN @SportBettype AS sbt ON b.Bettype = sbt.Bettype
			WHERE
				b.winlostdate BETWEEN @TempFromDate AND @todate 
				AND b.recommend = @Recommend --to improve performance
				AND b.custid = @CustID 
				AND sbt.ProductID = 8 
				AND b.statusID IN (111, 112, 113)
		END

		-- Microgaming RNG Casino, RNG Casino Single Wallet, Macau Games, Fishing World
		IF @ShowCS = 1 OR @ShowMGCRNG = 1 OR @ShowVB = 1 OR @ShowFW = 1
		BEGIN
			-- Up to yesterday settled ticket
			INSERT INTO #BetListByDateMem
			SELECT
				CASE
					WHEN sbt.ProductID = 6 THEN b.matchid
					WHEN sbt.ProductID = 17 THEN 205
					WHEN sbt.ProductID = 22 THEN 212
					WHEN sbt.ProductID = 24 THEN 219
				END AS Sporttype,
				@Username,
				b.transid,
				ISNULL(b.betid, 0),
				b.bettype,
				0 AS hdp1,
				0 AS hdp2,
				0 AS oddstype,
				0 AS Odds,
				0 AS modds,
				b.stake,
				b.actual_stake,
				'' AS betteam,
				b.status,
				b.refno,
				b.transdate,
				b.winlostdate,
				(b.winlost - b.actual_stake) AS Winlost,
				ABS(b.winlost - b.actual_stake) AS BetEffective,
				- (b.winlost - b.actual_stake) AS LicenseeWL,
				b.comm,
				b.playercomm,
				0 AS Liveindicator,
				0 AS Livehomescore,
				0 AS Liveawayscore,
				b.IP,
				0 AS LeagueID,
				0 AS MatchID,
				'' AS MatchCode,
				'' AS Race,
				0 AS HomeID,
				0 AS AwayID,
				0 AS Betstatus,
				CONVERT(BIT, 0) AS IsNeutral,
				b.currency,
				'' AS ShowTime,
				'' AS betcheck,
				CASE
					WHEN sbt.ProductID IN (6, 22, 24) THEN b.transdesc
					ELSE ''
				END AS transdesc
			FROM
				dbo.bettrans AS b WITH (NOLOCK)
				INNER JOIN @SportBettype AS sbt ON b.Bettype = sbt.Bettype
			WHERE
				b.winlostdate BETWEEN @TempFromDate AND @todate 
				AND b.winlostdate < @Yesterday
				AND b.recommend = @Recommend --to improve performance
				AND b.custid = @CustID 
				AND (sbt.ProductID IN (17, 22, 24)
					OR (sbt.ProductID = 6 AND sbt.SubProduct <> ''))
				AND b.statusID IN (111, 112, 113)

			IF @todate >= @Yesterday AND @TempFromDate <= @Today
			BEGIN
				-- Yesterday and today settled ticket
				INSERT INTO #BetListByDateMem
				SELECT
					CASE
						WHEN sbt.ProductID = 6 THEN b.matchid
						WHEN sbt.ProductID = 17 THEN 205
						WHEN sbt.ProductID = 22 THEN 212
						WHEN sbt.ProductID = 24 THEN 219
					END AS Sporttype,
					@Username,
					b.transid,
					ISNULL(b.BetID, 0),
					b.Bettype,
					0 AS hdp1,
					0 AS hdp2,
					0 AS oddstype,
					0 AS Odds,
					0 AS modds,
					SUM(brng.stake) AS Stake,
					SUM(brng.actual_stake) AS Actual_Stake,
					'' AS betteam,
					CASE 
						WHEN SUM(brng.winlost - brng.actual_stake) = 0 THEN 'Draw'
						WHEN SUM(brng.winlost - brng.actual_stake) > 0 THEN 'Won'
						WHEN SUM(brng.winlost - brng.actual_stake) < 0 THEN 'Lose'
					END AS Status,
					b.refno,
					b.transdate,
					b.winlostdate,
					SUM(brng.winlost - brng.actual_stake) AS Winlost,
					ABS(SUM(brng.winlost - brng.actual_stake)) AS BetEffective,
					SUM(- (brng.winlost - brng.actual_stake)) AS LicenseeWL,
					SUM(brng.comm) AS comm,
					SUM(brng.playercomm) AS playercomm,
					0 AS Liveindicator,
					0 AS Livehomescore,
					0 AS Liveawayscore,
					b.ip,
					0 AS LeagueID,
					0 AS MatchID,
					'' AS MatchCode,
					'' AS Race,
					0 AS HomeID,
					0 AS AwayID,
					0 AS Betstatus,
					CONVERT(BIT, 0) AS IsNeutral,
					b.currency,
					'' AS showtime,
					'' AS betcheck,
					CASE
						WHEN sbt.ProductID IN (6, 22, 24) THEN b.transdesc
						ELSE ''
					END AS transdesc
				FROM
					dbo.bettransRnG AS brng WITH (NOLOCK)
					INNER JOIN dbo.bettrans AS b WITH (NOLOCK) ON brng.RefNo = b.transid
					INNER JOIN @SportBettype AS sbt ON b.Bettype = sbt.Bettype
				WHERE b.winlostdate BETWEEN @TempFromDate AND @todate
					AND b.winlostdate BETWEEN @Yesterday AND @Today
					AND b.custid = @custid 
					AND (@currencyID = 0 OR b.currency = @currencyID) 
					AND (sbt.ProductID IN (17, 22, 24)
						OR (sbt.ProductID = 6 AND sbt.SubProduct <> ''))
					AND brng.statusID <> 0
				GROUP BY
					b.transid,
					ISNULL(b.betid, 0),
					b.bettype,
					b.refno,
					b.transdate,
					b.winlostdate,
					b.ip,
					b.currency,
					b.matchid,
					b.transdesc,
					sbt.ProductID
			END
		END

		-- AG Casino, AllBet
		IF @ShowAGC = 1 OR @ShowAB = 1
		BEGIN
			-- Up to yesterday settled ticket
			INSERT INTO #BetListByDateMem
			SELECT
				CASE
					WHEN sbt.ProductID = 11 THEN 250
					WHEN sbt.ProductID = 21 THEN 211
				END AS Sporttype,
				@Username, 
				b.TransID,
				ISNULL(b.BetID, 0),
				b.Bettype,
				0 AS hdp1,
				0 AS hdp2,
				0 AS oddstype,
				0 AS Odds,
				0 AS modds,
				b.stake,
				b.actual_stake,
				'' AS betteam,
				b.status,
				b.refno,
				b.Transdate,
				b.winlostdate,
				(b.winlost - b.actual_stake) AS Winlost,
				ABS(b.winlost - b.actual_stake) AS BetEffective,
				- (b.winlost - b.actual_stake) AS LicenseeWL,
				b.comm,
				b.playercomm,
				0 AS Liveindicator,
				0 AS Livehomescore,
				0 AS Liveawayscore,
				b.IP,
				0 AS LeagueID,
				0 AS MatchID,
				'' AS MatchCode,
				'' AS Race,
				0 AS HomeID,
				0 AS AwayID,
				0 AS Betstatus,
				CONVERT(BIT, 0) AS IsNeutral,
				b.currency,
				'' AS ShowTime,
				'' AS betcheck,
				'' AS transdesc
			FROM
				dbo.bettrans AS b WITH (NOLOCK)
				INNER JOIN @SportBettype AS sbt ON b.Bettype = sbt.Bettype
			WHERE
				b.winlostdate BETWEEN @TempFromDate AND @todate 
				AND b.winlostdate < @Yesterday
				AND b.recommend = @Recommend --to improve performance
				AND b.custid = @CustID 
				AND sbt.ProductID IN (11, 21)
				AND b.statusID IN (111, 112, 113)

			IF @todate >= @Yesterday AND @TempFromDate <= @Today
			BEGIN
				-- Yesterday and today settled ticket
				INSERT INTO #BetListByDateMem
				SELECT
					CASE
						WHEN sbt.ProductID = 11 THEN 250
						WHEN sbt.ProductID = 21 THEN 211
					END AS Sporttype,
					@Username,
					b.transid,
					ISNULL(b.BetID, 0),
					b.Bettype,
					0 AS hdp1,
					0 AS hdp2,
					0 AS oddstype,
					0 AS Odds,
					0 AS modds,
					SUM(blc.stake) AS Stake,
					SUM(blc.actual_stake) AS Actual_Stake,
					'' AS betteam,
					CASE 
						WHEN SUM(blc.winlost - blc.actual_stake) = 0 THEN 'Draw'
						WHEN SUM(blc.winlost - blc.actual_stake) > 0 THEN 'Won'
						WHEN SUM(blc.winlost - blc.actual_stake) < 0 THEN 'Lose'
					END AS Status,
					b.refno,
					b.transdate,
					b.winlostdate,
					SUM(blc.winlost - blc.actual_stake) AS Winlost,
					ABS(SUM(blc.winlost - blc.actual_stake)) AS BetEffective,
					SUM(- (blc.winlost - blc.actual_stake)) AS LicenseeWL,
					SUM(blc.comm) AS comm,
					SUM(blc.playercomm) AS playercomm,
					0 AS Liveindicator,
					0 AS Livehomescore,
					0 AS Liveawayscore,
					b.ip,
					0 AS LeagueID,
					0 AS MatchID,
					'' AS MatchCode,
					'' AS Race,
					0 AS HomeID,
					0 AS AwayID,
					0 AS Betstatus,
					CONVERT(BIT, 0) AS IsNeutral,
					b.currency,
					'' AS showtime,
					'' AS betcheck,
					'' AS transdesc
				FROM
					dbo.bettransLC AS blc WITH (NOLOCK)
					INNER JOIN dbo.bettrans AS b WITH (NOLOCK) ON blc.RefNo = b.transid
					INNER JOIN @SportBettype AS sbt ON b.Bettype = sbt.Bettype
				WHERE b.winlostdate BETWEEN @TempFromDate AND @todate
					AND b.winlostdate BETWEEN @Yesterday AND @Today
					AND b.custid = @custid 
					AND (@currencyID = 0 OR b.currency = @currencyID) 
					AND sbt.ProductID IN (11, 21)
					AND blc.statusID <> 0
				GROUP BY
					b.transid,
					ISNULL(b.BetID, 0),
					b.Bettype,
					b.refno,
					b.transdate,
					b.winlostdate,
					b.IP,
					b.currency,
					sbt.ProductID
			END
		END
	END

	IF @Fromdate <= @MoveBetsDay AND @ToDate >= @BalanceUpDay
	BEGIN
		IF @ToDate >= @MoveBetsDay
			SET @TempToDate = @MoveBetsDay
		ELSE
			SET @TempToDate = @ToDate

		IF @BalanceUpDay < @FromDate
			SELECT @BalanceUpDay = @FromDate

		DELETE FROM #TempBetList

		-- BA tickets
		INSERT INTO #TempBetList
		SELECT
			b.transid,
			ISNULL(b.betid, 0),
			b.bettype,
			b.hdp1,
			b.hdp2,
			b.oddstype,
			b.odds,
			b.modds,
			b.stake,
			b.actual_stake,
			b.betteam,
			b.status,
			b.refno,
			b.transdate,
			b.winlostdate,
			(b.winlost-actual_stake),
			ABS(b.winlost-actual_stake),
			0 AS LicenseeWL,
			b.comm,
			b.playercomm,
			b.liveindicator,
			b.livehomescore,
			b.liveawayscore,
			b.ip,
			b.currency,
			b.matchid,
			b.betcheck,
			ISNULL(b.transdesc, '') AS transdesc
		FROM
			dbo.bettrans14 AS b WITH (NOLOCK)
			INNER JOIN DBLIC.bodb_Licensee.dbo.LicenseeBATransaction AS BA WITH (NOLOCK) ON b.transid = BA.transid
		WHERE
			b.winlostdate BETWEEN @BalanceUpDay AND @TempToDate
			AND b.recommend = @Recommend
			AND b.custid = @custid
			AND b.statusID IN (111, 112, 113)
			AND b.bettype NOT IN (901, 902, 903)

		IF @ShowBA = 1
		BEGIN
			-- Sportsbook
			INSERT INTO #BetListByDateMem
			SELECT
				m.Sporttype,
				@Username,
				b.TransID,
				b.BetID,
				b.Bettype,
				b.hdp1,
				b.hdp2,
				b.OddsType,
				b.Odds,
				b.modds,
				b.stake,
				b.actual_stake,
				b.betteam,
				b.status,
				b.refno,
				b.Transdate,
				b.winlostdate,
				b.winlost,
				b.BetEffective,
				b.LicenseeWL,
				b.comm,
				b.playercomm,
				b.Liveindicator,
				b.Livehomescore,
				b.Liveawayscore,
				b.IP,
				m.LeagueID,
				m.MatchID,
				m.MatchCode,
				'' AS Race,
				m.HomeID,
				m.AwayID,
				m.Betstatus,
				ISNULL(m.isNeutral, CONVERT(BIT,0)) AS IsNeutral,
				b.currency,
				'' AS ShowTime,
				b.betcheck,
				b.transdesc
			FROM
				#TempBetList AS b
				INNER JOIN dbo.match14 AS m WITH (NOLOCK) ON b.matchid = m.matchid
				INNER JOIN @SportBettype AS sbt ON b.Bettype = sbt.Bettype
			WHERE sbt.ProductID = 1 AND sbt.EventType = 1
		
			-- Outright
			INSERT INTO #BetListByDateMem
			SELECT
				l.sporttype,
				@Username, 
				b.TransID,
				b.BetID,
				b.Bettype,
				CONVERT(FLOAT, b.hdp1) AS hdp1,
				CONVERT(FLOAT, b.hdp2) AS hdp2,
				0 AS OddsType, 
				b.Odds, 
				b.modds,
				b.stake,
				b.actual_stake, 
				'' AS Betteam,
				b.Status,
				b.refno,
				b.Transdate,
				b.winlostdate,
				b.winlost,
				b.BetEffective,
				b.LicenseeWL,
				b.comm,
				b.playercomm,
				0 AS LiveIndicator, 
				b.LiveHomescore, 
				b.LiveAwayscore,
				b.IP,
				m.LeagueID,
				m.OrId, --MatchID
				m.MatchCode,
				m.GroupMatch,--Race
				m.TeamID, --HomeID
				0, --AwayID
				0, --Betstatus
				CONVERT(BIT,0) AS IsNeutral,
				b.currency,
				'' AS ShowTime,
				'' AS betcheck,
				'' AS transdesc
			FROM
				#TempBetList AS b
				INNER JOIN dbo.outright14 AS m WITH (NOLOCK) ON b.matchid = m.orid
				INNER JOIN dbo.league AS l WITH (NOLOCK) ON m.leagueID = l.leagueID
				INNER JOIN @SportBettype AS sbt ON b.Bettype = sbt.Bettype
			WHERE sbt.ProductID = 1 AND sbt.EventType = 2

			-- Mix Parlay + Combination Mixed Parlay
			INSERT INTO #BetListByDateMem
			SELECT
				0, --Sporttype
				@Username, 
				b.TransID,
				b.BetID,
				b.bettype,
				b.hdp1,
				b.hdp2,
				0 AS OddsType,
				b.Odds,
				b.modds,
				b.stake,
				b.actual_stake,
				b.betteam,
				b.Status,
				b.refno,
				b.Transdate,
				b.winlostdate,
				b.winlost,
				b.BetEffective,
				b.LicenseeWL,
				b.comm,
				b.playercomm,
				b.Liveindicator,
				b.Livehomescore,
				b.Liveawayscore,
				b.IP,
				0, --LeagueID
				0, --MatchID
				'',--MatchCode
				'',--Race
				0, --HomeID
				0, --AwayID
				0, --Betstatus
				CONVERT(BIT,0) AS IsNeutral,
				b.currency,
				'' AS ShowTime,
				ISNULL(b.betcheck, '') AS BetCheck,
				'' AS transdesc
			FROM
				#TempBetList AS b
				INNER JOIN @SportBettype AS sbt ON b.Bettype = sbt.Bettype
			WHERE
				sbt.ProductID = 1 
				AND sbt.EventType = 0 
				AND b.matchid IN (9, 29)
		END

		-- Sportsbook
		IF @ShowSB = 1
		BEGIN
			INSERT INTO #BetListByDateMem
			SELECT
				m.Sporttype, 
				@Username, 
				b.TransID,
				ISNULL(b.BetID,0),
				b.Bettype,
				b.hdp1, 
				b.hdp2, 
				b.Oddstype,
				b.odds,
				b.modds,
				b.stake,
				b.actual_stake, 
				b.betteam,
				b.status,
				b.refno,
				b.Transdate,
				b.winlostdate,
				(b.winlost-actual_stake),
				ABS(b.winlost-actual_stake),
				- (b.winlost-b.actual_stake) AS LicenseeWL,
				b.comm,
				b.playercomm,
				b.Liveindicator,
				b.Livehomescore,
				b.Liveawayscore,
				b.ip,
				m.LeagueID,
				m.MatchID,
				m.MatchCode,
				'' AS Race,
				m.HomeID,
				m.AwayID,
				m.Betstatus,
				ISNULL(m.isNeutral, CONVERT(BIT,0)) AS IsNeutral,
				b.currency,
				'' AS ShowTime,
				b.betcheck,
				ISNULL(b.transdesc, '') AS transdesc
			FROM
				dbo.bettrans14 AS b WITH (NOLOCK, INDEX=bettrans1423)
				INNER JOIN dbo.match14 AS m WITH (NOLOCK) ON b.matchid = m.matchid
				INNER JOIN @SportBettype AS sbt ON b.Bettype = sbt.Bettype
			WHERE
				b.winlostdate BETWEEN @BalanceUpDay AND @TempToDate 
				AND b.recommend = @Recommend 
				AND b.custid = @custid 
				AND b.matchid > 0 
				AND sbt.ProductID = 1
				AND sbt.EventType = 1
				AND b.bettype NOT IN (901, 902, 903) 
				AND b.statusID IN (111, 112, 113)
				AND b.transid NOT IN (SELECT Transid FROM #TempBetList) 

			-- Mix Parlay + Combination Mixed Parlay
			INSERT INTO #BetListByDateMem
			SELECT
				0, --Sporttype
				@Username,
				b.TransID,
				ISNULL(b.BetID,0),
				b.bettype,
				b.hdp1,
				b.hdp2,
				0 AS OddsType,
				b.Odds,
				b.modds,
				b.stake,
				b.actual_stake,
				b.betteam,
				b.Status,
				b.refno,
				b.Transdate,
				b.winlostdate,
				(b.winlost-actual_stake),
				ABS(b.winlost-actual_stake),
				- (b.winlost-b.actual_stake) AS LicenseeWL,
				b.comm,
				b.playercomm,
				b.Liveindicator,
				b.Livehomescore,
				b.Liveawayscore,
				b.ip,
				0, --LeagueID
				0, --MatchID
				'',--MatchCode
				'',--Race
				0, --HomeID
				0, --AwayID
				0, --Betstatus
				CONVERT(BIT,0) AS isNeutral,
				b.currency,
				'' AS ShowTime,
				ISNULL(b.betcheck, '') AS BetCheck,
				'' AS transdesc
			FROM
				dbo.bettrans14 AS b WITH (NOLOCK, INDEX=bettrans1423)
				INNER JOIN @SportBettype AS sbt ON b.Bettype = sbt.Bettype
			WHERE
				b.winlostdate BETWEEN @BalanceUpDay AND @TempToDate 
				AND b.recommend = @Recommend
				AND b.custid = @custid
				AND sbt.ProductID = 1
				AND sbt.EventType = 0
				AND b.matchid IN (9, 29)
				AND b.statusID IN (111, 112, 113)
				AND b.transid NOT IN (SELECT Transid FROM #TempBetList)

			INSERT INTO #BetListByDateMem
			SELECT
				l.sporttype,
				@Username,
				b.TransID,
				ISNULL(b.BetID,0),
				b.Bettype,
				CONVERT(FLOAT, b.hdp1) AS hdp1,
				CONVERT(FLOAT, b.hdp2) AS hdp2,
				0 AS OddsType,
				b.Odds,
				b.modds,
				b.stake,
				b.actual_stake,
				'' AS Betteam,
				b.Status,
				b.refno,
				b.Transdate,
				b.winlostdate,
				(b.winlost-actual_stake),
				ABS(b.winlost-actual_stake),
				- (b.winlost-b.actual_stake) AS LicenseeWL,
				b.comm,
				b.playercomm,
				0 AS LiveIndicator,
				b.LiveHomescore,
				b.LiveAwayscore,
				b.ip,
				m.LeagueID,
				m.OrId, --MatchID
				m.MatchCode,
				m.GroupMatch AS Race,
				m.TeamID, --HomeID
				0, --AwayID
				0, --Betstatus
				CONVERT(BIT,0) AS isNeutral,
				b.currency,
				'' AS ShowTime,
				'' AS betcheck,
				'' AS transdesc
			FROM
				dbo.bettrans14 AS b WITH (NOLOCK, INDEX=bettrans1423)
				INNER JOIN dbo.Outright14 AS m WITH (NOLOCK) ON b.matchid = m.orid
				INNER JOIN dbo.league AS l WITH (NOLOCK) ON m.leagueID = l.leagueID
				INNER JOIN @SportBettype AS sbt ON b.Bettype = sbt.Bettype
			WHERE
				b.winlostdate BETWEEN @BalanceUpDay AND @TempToDate 
				AND b.recommend = @Recommend 
				AND b.custid = @custid 
				AND sbt.ProductID = 1 
				AND sbt.EventType = 2 
				AND b.statusID IN (111, 112, 113)
				AND b.transid NOT IN (SELECT Transid FROM #TempBetList)
		END

		-- BetTrade
		IF @ShowBT = 1
		BEGIN
			INSERT INTO #BetListByDateMem
			SELECT
				m.Sporttype,
				@Username,
				b.TransID,
				ISNULL(ob.bettype,0),
				b.Bettype,
				b.hdp1,
				b.hdp2,
				b.Oddstype,
				ob.odds,
				b.modds,
				ob.stake,
				b.actual_stake, 
				b.betteam,
				b.status,
				b.refno,
				b.Transdate,
				b.winlostdate,
				(b.winlost-b.actual_stake),
				ABS(b.winlost-b.actual_stake),
				- (b.winlost-b.actual_stake) AS LicenseeWL,
				CASE WHEN b.bettype = 903 THEN b.awinlost ELSE b.comm END AS comm,
				b.playercomm,
				b.Liveindicator,
				b.Livehomescore,
				b.Liveawayscore,
				b.ip,
				m.LeagueID,
				m.MatchID,
				m.MatchCode,
				'' AS Race,
				m.HomeID,
				m.AwayID,
				m.Betstatus,
				ISNULL(m.isNeutral, CONVERT(BIT,0)) AS IsNeutral,
				b.currency,
				'' AS ShowTime,
				b.betcheck,
				'' AS transdesc
			FROM
				dbo.bettrans14 AS b WITH (NOLOCK, INDEX=bettrans1423)
				INNER JOIN dbo.bettrans14 AS ob WITH (NOLOCK) ON b.refno = ob.transid
				INNER JOIN dbo.match14 AS m WITH (NOLOCK) ON b.matchid = m.matchid
				INNER JOIN @SportBettype AS sbt ON b.Bettype = sbt.Bettype
			WHERE
				b.winlostdate BETWEEN @BalanceUpDay AND @TempToDate 
				AND b.recommend = @Recommend 
				AND b.custid = @custid 
				AND b.matchid > 0 
				AND sbt.ProductID = 1
				AND sbt.EventType = 1
				AND b.bettype IN (901, 902, 903)
				AND b.statusID IN (111, 112, 113)
		END

		-- Horse Racing
		IF @ShowRB = 1
		BEGIN
			INSERT INTO #BetListByDateMem
			SELECT
				l.sporttype,
				@Username, 
				b.transid,
				ISNULL(b.betid,0),
				b.bettype,
				b.hdp1,
				b.hdp2,
				0 AS OddsType,
				b.Odds, 
				b.modds,
				b.stake,
				b.actual_stake,
				'' AS Betteam,
				b.Status,
				b.refno,
				b.Transdate,
				b.winlostdate,
				(b.winlost-actual_stake),
				ABS(b.winlost-actual_stake),
				b.awinlost,
				b.comm,
				b.playercomm,
				0 AS LiveIndicator,
				b.LiveHomescore,
				b.LiveAwayscore,
				b.ip,
				m.LeagueID,
				m.OrId,--0, --MatchID
				m.MatchCode,
				m.GroupMatch AS Race,
				m.TeamID, --HomeID
				0, --AwayID
				0, --Betstatus
				CONVERT(BIT,0) AS isNeutral,
				b.currency,
				'' AS ShowTime,
				'' AS betcheck,
				'' AS transdesc
			FROM
				dbo.bettrans14 AS b WITH (NOLOCK, INDEX=bettrans1423)
				INNER JOIN dbo.Outright14 AS m WITH (NOLOCK) ON b.matchid = m.orid
				INNER JOIN dbo.league AS l WITH (NOLOCK) ON m.leagueID = l.leagueID
				INNER JOIN @SportBettype AS sbt ON b.Bettype = sbt.Bettype
			WHERE
				b.winlostdate BETWEEN @BalanceUpDay AND @TempToDate 
				AND b.recommend = @Recommend 
				AND b.custid = @custid 
				AND sbt.ProductID = 2 
				AND b.statusID IN (111, 112, 113)
		END

		-- Number Game, Live Casino
		IF @ShowNG = 1 OR @ShowLC = 1
		BEGIN
			INSERT INTO #BetListByDateMem
			SELECT
				m.Sporttype, 
				@Username, 
				b.TransID,
				ISNULL(b.BetID,0),
				b.Bettype,
				CONVERT(FLOAT, b.hdp1) AS hdp1, 
				CONVERT(FLOAT, b.hdp2) AS hdp2,
				b.Oddstype,
				b.odds,
				b.modds,
				b.stake,
				b.actual_stake, 
				b.betteam,
				b.status,
				b.refno,
				b.Transdate,
				b.winlostdate,
				(b.winlost-actual_stake),
				ABS(b.winlost-actual_stake),
				- (b.winlost-b.actual_stake) AS LicenseeWL,
				b.comm,
				b.playercomm,
				b.Liveindicator,
				b.Livehomescore,
				b.Liveawayscore,
				b.ip,
				m.LeagueID,
				m.MatchID,
				m.MatchCode,
				'' AS Race,
				m.HomeID,
				m.AwayID,
				m.Betstatus,
				CONVERT(BIT,0) AS IsNeutral,
				b.currency,
				CASE WHEN sbt.ProductID = 4 THEN ISNULL(m.showtime,'') ELSE '' END AS ShowTime,
				'' AS betcheck,
				'' AS transdesc
			FROM
				dbo.bettrans14 AS b WITH (NOLOCK, INDEX=bettrans1423)
				INNER JOIN dbo.match14 AS m WITH (NOLOCK) ON b.matchid = m.matchid 
				INNER JOIN @SportBettype AS sbt ON b.Bettype = sbt.Bettype
			WHERE
				b.winlostdate BETWEEN @BalanceUpDay AND @TempToDate 
				AND b.recommend = @Recommend --to improve performance
				AND b.custid = @CustID 
				AND sbt.ProductID IN (3, 4)
				AND b.statusID IN (111, 112, 113)
		END

		-- Virtual Sport
		IF @ShowVS = 1
		BEGIN
			INSERT INTO #BetListByDateMem
			SELECT
				m.Sporttype, 
				@Username, 
				b.TransID,
				ISNULL(b.BetID,0),
				b.Bettype,
				CONVERT(FLOAT, b.hdp1) AS hdp1,
				CONVERT(FLOAT, b.hdp2) AS hdp2,
				b.Oddstype,
				b.odds,
				b.modds,
				b.stake,
				b.actual_stake,
				b.betteam,
				b.status,
				b.refno,
				b.Transdate,
				b.winlostdate,
				(b.winlost-actual_stake),
				ABS(b.winlost-actual_stake),
				- (b.winlost-b.actual_stake) AS LicenseeWL,
				b.comm,
				b.playercomm,
				b.Liveindicator,
				b.Livehomescore,
				b.Liveawayscore,
				b.ip,
				m.LeagueID,
				m.MatchID,
				m.MatchCode,
				'' AS Race,
				m.HomeID,
				m.AwayID,
				m.Betstatus,
				CONVERT(BIT,0) AS IsNeutral,
				b.currency,
				'' AS ShowTime,
				'' AS betcheck,
				'' AS transdesc
			FROM
				dbo.bettrans14 AS b WITH (NOLOCK, INDEX=bettrans1423)
				INNER JOIN dbo.match14 AS m WITH (NOLOCK) ON b.matchid = m.matchid 
				INNER JOIN @SportBettype AS sbt ON b.Bettype = sbt.Bettype
			WHERE
				b.winlostdate BETWEEN @BalanceUpDay AND @TempToDate 
				AND b.recommend = @Recommend --to improve performance
				AND b.custid = @CustID 
				AND sbt.ProductID = 5 
				AND sbt.EventType = 1
				AND b.statusID IN (111, 112, 113)
			
			UNION ALL 
			SELECT
				r.Sporttype,
				@Username,
				b.TransID,
				ISNULL(b.BetID,0),
				b.Bettype,
				CONVERT(FLOAT, b.hdp1) AS hdp1,
				CONVERT(FLOAT, b.hdp2) AS hdp2,
				b.Oddstype,
				b.Odds,
				b.modds,
				b.stake,
				b.actual_stake,
				b.betteam,
				b.status,
				b.refno,
				b.Transdate,
				b.winlostdate,
				(b.winlost-actual_stake),
				ABS(b.winlost-actual_stake),
				- (b.winlost-b.actual_stake) AS LicenseeWL,
				b.comm,
				b.playercomm,
				b.Liveindicator,
				b.Livehomescore,
				b.Liveawayscore,
				b.ip,
				r.LeagueID,
				o.EventID matchid,
				CONVERT(VARCHAR(50),o.RacerNum) MatchCode,
				b.oddsid AS Race,
				o.RacerID HomeID,
				0 AwayID,
				r.Betstatus,
				CONVERT(BIT,0) AS IsNeutral,
				b.currency,
				CONVERT(VARCHAR(20),r.EventTime) AS ShowTime,
				'' AS betcheck,
				'' AS transdesc
			FROM
				dbo.bettrans14 AS b WITH (NOLOCK)
				INNER JOIN dbo.VSOutright14 AS o WITH (NOLOCK) ON b.oddsid = o.Orid
				INNER JOIN dbo.VSRaceInfo AS r WITH (NOLOCK) ON r.EventID = o.EventID
				INNER JOIN @SportBettype AS sbt ON b.Bettype = sbt.Bettype
			WHERE
				b.winlostdate BETWEEN @BalanceUpDay AND @TempToDate 
				AND b.recommend = @Recommend --to improve performance
				AND b.custid = @CustID 
				AND sbt.ProductID = 5 
				AND sbt.EventType = 3
				AND b.statusID IN (111, 112, 113)
		END

		-- RNG Casino, AG Casino, Microgaming Live Casino, Microgaming RNG Casino, AllBet, Macau Games, Fishing World
		IF @ShowCS = 1 OR @ShowMGCLC = 1 OR @ShowMGCRNG = 1 OR @ShowAGC = 1 OR @ShowAB = 1 OR @ShowVB = 1 OR @ShowFW = 1
		BEGIN
			INSERT INTO #BetListByDateMem
			SELECT
				CASE
					WHEN sbt.ProductID = 6 AND sbt.SubProduct = '' THEN 251
					WHEN sbt.ProductID = 6 AND sbt.SubProduct <> '' THEN b.matchid
					WHEN sbt.ProductID = 11 THEN 250
					WHEN sbt.ProductID = 13 THEN 203
					WHEN sbt.ProductID = 17 THEN 205
					WHEN sbt.ProductID = 21 THEN 211
					WHEN sbt.ProductID = 22 THEN 212
					WHEN sbt.ProductID = 24 THEN 219
				END AS Sporttype,
				@Username, 
				b.TransID,
				ISNULL(b.BetID, 0),
				b.Bettype,
				CASE
					WHEN sbt.ProductID = 6 AND sbt.SubProduct = '' THEN b.hdp1
					ELSE 0
				END AS hdp1,
				CASE
					WHEN sbt.ProductID = 6 AND sbt.SubProduct = '' THEN b.hdp2
					ELSE 0
				END AS hdp2,
				CASE
					WHEN sbt.ProductID = 6 AND sbt.SubProduct = '' THEN b.oddstype
					ELSE 0
				END AS Oddstype,
				CASE
					WHEN sbt.ProductID = 6 AND sbt.SubProduct = '' THEN b.Odds
					ELSE 0
				END AS Odds,
				CASE
					WHEN sbt.ProductID = 6 AND sbt.SubProduct = '' THEN b.modds
					ELSE 0
				END AS modds,
				b.stake,
				b.actual_stake,
				CASE
					WHEN sbt.ProductID = 6 AND sbt.SubProduct = '' THEN b.Betteam
					ELSE ''
				END AS Betteam,
				b.status,
				b.refno,
				b.Transdate,
				b.winlostdate,
				(b.winlost - actual_stake) AS WinLost,
				ABS(b.winlost - actual_stake) AS BetEffective,
				- (b.winlost - b.actual_stake) AS LicenseeWL,
				b.comm,
				b.playercomm,
				b.liveindicator,
				b.livehomescore,
				b.liveawayscore,
				b.ip,
				0 AS LeagueID,
				CASE
					WHEN sbt.ProductID = 6 AND sbt.SubProduct = '' THEN b.bettype
					ELSE 0
				END AS MatchID,
				'' AS MatchCode,
				'' AS Race,
				0 AS HomeID,
				0 AS AwayID,
				0 AS Betstatus,
				CONVERT(BIT, 0) AS IsNeutral,
				b.currency,
				'' AS ShowTime,
				CASE
					WHEN sbt.ProductID = 13 THEN b.betcheck
					ELSE ''
				END AS betcheck,
				CASE
					WHEN sbt.ProductID = 6 AND sbt.SubProduct <> '' THEN b.transdesc
					WHEN sbt.ProductID IN (22, 24) THEN b.transdesc
					ELSE ''
				END AS transdesc
			FROM
				dbo.bettrans14 AS b WITH (NOLOCK, INDEX=bettrans1423)
				INNER JOIN @SportBettype AS sbt ON b.Bettype = sbt.Bettype
			WHERE
				b.winlostdate BETWEEN @BalanceUpDay AND @TempToDate 
				AND b.recommend = @Recommend --to improve performance
				AND b.custid = @CustID 
				AND sbt.ProductID IN (6, 11, 13, 17, 21, 22, 24)
				AND b.statusID IN (111, 112, 113)
		END

		-- Keno
		IF @ShowKN = 1 
		BEGIN
			INSERT INTO #BetListByDateMem
			SELECT
				202 Sporttype, 
				@Username, 
				b.TransID,
				ISNULL(b.BetID,0),
				b.Bettype,
				0 AS hdp1, 
				0 AS hdp2,
				b.Oddstype,
				b.odds,
				b.modds,
				b.stake,
				b.actual_stake, 
				ChoiceID betteam,
				b.status,
				b.refno,
				b.Transdate,
				b.winlostdate,
				(b.winlost-actual_stake),
				ABS(b.winlost-actual_stake),
				- (b.winlost-b.actual_stake) AS LicenseeWL,
				b.comm,
				b.playercomm,
				b.Liveindicator,
				b.Livehomescore,
				b.Liveawayscore,
				b.IP,
				0 AS LeagueID,
				GameId AS MatchID,
				'' AS MatchCode,
				'' AS Race,
				0 AS HomeID,
				0 AS AwayID,
				0 AS Betstatus,
				CONVERT(BIT,0) AS IsNeutral,
				b.currency,
				''  AS ShowTime,
				'' AS betcheck,
				'' AS transdesc
			FROM
				dbo.bettrans14 AS b WITH (NOLOCK, INDEX=bettrans1423)
				CROSS APPLY dbo.f_ParseTransDesc(b.transdesc, b.bettype)
				INNER JOIN @SportBettype AS sbt ON b.Bettype = sbt.Bettype
			WHERE
				b.winlostdate BETWEEN @BalanceUpDay AND @TempToDate 
				AND b.recommend = @Recommend --to improve performance
				AND b.custid = @CustID 
				AND sbt.ProductID = 8 
				AND b.statusID IN (111, 112, 113)
		END
	END

	IF @FromDate < @BalanceUpDay
	BEGIN
		IF @todate >= DATEADD(dd, -1, @BalanceUpDay)
			SET @TempToDate = DATEADD(dd, -1, @BalanceUpDay)
		ELSE
			SET @TempToDate = @todate

		DELETE FROM #TempBetList

		-- BA tickets
		INSERT INTO #TempBetList
		SELECT
			b.TransID,
			ISNULL(b.BetID,0),
			b.Bettype,
			b.hdp1,
			b.hdp2,
			b.Oddstype,
			b.odds,
			b.modds,
			b.stake,
			b.actual_stake, 
			b.betteam,
			b.status,
			b.refno,
			b.Transdate,
			b.winlostdate,
			(b.winlost - actual_stake),
			ABS(b.winlost - actual_stake),
			0 AS LicenseeWL,
			CASE WHEN b.bettype = 903 THEN b.awinlost ELSE b.comm END AS comm,
			b.playercomm,
			b.Liveindicator,
			b.Livehomescore,
			b.Liveawayscore,
			b.IP,
			b.currency,
			b.matchid,
			b.betcheck,
			ISNULL(b.transdesc, '') AS transdesc
		FROM
			bodb_archive.dbo.bettrans_bk AS b WITH (NOLOCK, INDEX=IX_custid)
			INNER JOIN DBLIC.bodb_Licensee.dbo.LicenseeBATransaction BA WITH (NOLOCK) ON b.transid = BA.transid
		WHERE
			b.winlostdate BETWEEN @fromdate AND @TempToDate 
			AND b.recommend = @Recommend
			AND b.custid = @custid 
			AND b.statusID IN (111, 112, 113)
			AND b.bettype NOT IN (901, 902, 903) 

		IF @ShowBA = 1
		BEGIN
			-- Sportsbook
			INSERT INTO #BetListByDateMem
			SELECT
				m.Sporttype, 
				@Username, 
				b.TransID,
				b.BetID,
				b.Bettype,
				b.hdp1, 
				b.hdp2,
				b.OddsType,
				b.Odds,
				b.modds,
				b.stake,
				b.actual_stake,
				b.betteam,
				b.status,
				b.refno,
				b.Transdate,
				b.winlostdate,
				b.winlost,
				b.BetEffective,
				b.LicenseeWL,
				b.comm,
				b.playercomm,
				b.Liveindicator,
				b.Livehomescore,
				b.Liveawayscore,
				b.IP,
				m.LeagueID,
				m.MatchID,
				m.MatchCode,
				'' AS Race,
				m.HomeID,
				m.AwayID,
				m.Betstatus,
				ISNULL(m.isNeutral, CONVERT(BIT,0)) AS IsNeutral,
				b.currency,
				'' AS ShowTime,
				b.betcheck,
				b.transdesc
			FROM
				#TempBetList AS b
				INNER JOIN bodb_Archive.dbo.MATCH_BK AS m WITH (NOLOCK) ON b.matchid = m.matchid
				INNER JOIN @SportBettype sbt ON b.Bettype = sbt.Bettype
			WHERE sbt.ProductID = 1 AND sbt.EventType = 1
		
			-- Outright
			INSERT INTO #BetListByDateMem
			SELECT
				l.sporttype,
				@Username,
				b.TransID,
				b.BetID,
				b.Bettype,
				CONVERT(FLOAT, b.hdp1) AS hdp1,
				CONVERT(FLOAT, b.hdp2) AS hdp2,
				0 AS OddsType, 
				b.Odds, 
				b.modds,
				b.stake,
				b.actual_stake, 
				'' AS Betteam,
				b.Status,
				b.refno,
				b.Transdate,
				b.winlostdate,
				b.winlost,
				b.BetEffective,
				b.LicenseeWL,
				b.comm,
				b.playercomm,
				0 AS LiveIndicator,
				b.LiveHomescore,
				b.LiveAwayscore,
				b.IP,
				m.LeagueID,
				m.OrId,--0, --MatchID
				m.MatchCode,
				m.GroupMatch,--Race
				m.TeamID, --HomeID
				0, --AwayID
				0, --Betstatus
				CONVERT(BIT,0) AS IsNeutral,
				b.currency,
				'' AS ShowTime,
				'' AS betcheck,
				'' AS transdesc
			FROM
				#TempBetList AS b
				INNER JOIN bodb_archive.dbo.Outright_BK AS m WITH (NOLOCK) ON b.matchid = m.orid
				INNER JOIN dbo.league AS l WITH (NOLOCK) ON m.leagueID = l.leagueID
				INNER JOIN @SportBettype AS sbt ON b.Bettype = sbt.Bettype
			WHERE sbt.ProductID = 1 AND sbt.EventType = 2

			-- Mix Parlay + Combination Mixed Parlay
			INSERT INTO #BetListByDateMem
			SELECT
				0, --Sporttype
				@Username, 
				CASE WHEN ISNULL(b.BetID,0)=0 THEN b.transid ELSE betid END AS transid, 
				b.BetID,
				b.bettype,
				b.hdp1,
				b.hdp2,
				0 AS OddsType,
				b.Odds, 
				b.modds,
				b.stake,
				b.actual_stake,
				b.betteam,
				b.Status,
				b.refno,
				b.Transdate,
				b.winlostdate,
				b.winlost,
				b.BetEffective,
				b.LicenseeWL,
				b.comm,
				b.playercomm,
				b.Liveindicator,
				b.Livehomescore,
				b.Liveawayscore,
				b.IP,
				0, --LeagueID
				0, --MatchID
				'',--MatchCode
				'',--Race
				0, --HomeID
				0, --AwayID
				0, --Betstatus
				CONVERT(BIT,0) AS IsNeutral,
				b.currency,
				'' AS ShowTime,
				ISNULL(b.betcheck, '') AS BetCheck,
				'' AS transdesc
			FROM
				#TempBetList AS b
				INNER JOIN @SportBettype sbt ON b.Bettype = sbt.Bettype
			WHERE
				sbt.ProductID = 1 
				AND sbt.EventType = 0 
				AND b.matchid IN (9, 29)
		END

		-- Sportsbook
		IF @ShowSB = 1
		BEGIN
			INSERT INTO #BetListByDateMem
			SELECT
				m.Sporttype, 
				@Username, 
				b.TransID,
				ISNULL(b.BetID,0),
				b.Bettype,
				b.hdp1,
				b.hdp2,
				b.Oddstype,
				b.odds,
				b.modds,
				b.stake,
				b.actual_stake, 
				b.betteam,
				b.status,
				b.refno,
				b.Transdate,
				b.winlostdate,
				(b.winlost-actual_stake),
				ABS(b.winlost-actual_stake),
				- (b.winlost-b.actual_stake) AS LicenseeWL,
				CASE WHEN b.bettype = 903 THEN b.awinlost ELSE b.comm END AS comm,
				b.playercomm,
				b.Liveindicator,
				b.Livehomescore,
				b.Liveawayscore,
				b.IP,
				m.LeagueID,
				m.MatchID,
				m.MatchCode,
				'' AS Race,
				m.HomeID,
				m.AwayID,
				m.Betstatus,
				ISNULL(m.isNeutral, CONVERT(BIT,0)) AS IsNeutral,
				b.currency,
				'' AS ShowTime,
				b.betcheck,
				ISNULL(b.transdesc, '') AS transdesc
			FROM
				bodb_archive.dbo.bettrans_bk AS b WITH (NOLOCK, INDEX=IX_custid)
				INNER JOIN bodb_archive.dbo.match_BK AS m WITH (NOLOCK) ON b.matchid = m.matchid
				INNER JOIN @SportBettype AS sbt ON b.Bettype = sbt.Bettype
			WHERE
				b.winlostdate BETWEEN @fromdate AND @TempToDate 
				AND b.custid = @custid 
				AND b.recommend = @Recommend 
				AND b.statusID IN (111, 112, 113)
				AND sbt.ProductID = 1 
				AND sbt.EventType = 1 
				AND b.bettype NOT IN (901, 902, 903) 
				AND b.transid NOT IN (SELECT Transid FROM #TempBetList) 

			-- Mix Parlay + Combination Mixed Parlay
			INSERT INTO #BetListByDateMem
			SELECT
				0, --Sporttype
				@Username, 
				b.TransID,
				ISNULL(b.BetID,0),
				b.bettype,
				b.hdp1, 
				b.hdp2, 
				0 AS OddsType,
				b.Odds, 
				b.modds,
				b.stake,
				b.actual_stake, 
				b.betteam,
				b.Status,
				b.refno,
				b.Transdate,
				b.winlostdate,
				(b.winlost-actual_stake),
				ABS(b.winlost-actual_stake),
				- (b.winlost-b.actual_stake) AS LicenseeWL,
				b.comm,
				b.playercomm,
				b.Liveindicator,
				b.Livehomescore,
				b.Liveawayscore,
				b.IP,
				0, --LeagueID
				0, --MatchID
				'',--MatchCode
				'',--Race
				0, --HomeID
				0, --AwayID
				0, --Betstatus
				CONVERT(BIT,0) AS IsNeutral,
				b.currency,
				'' AS ShowTime,
				ISNULL(b.betcheck, '') AS BetCheck,
				'' AS transdesc
			FROM
				bodb_archive.dbo.bettrans_bk AS b WITH (NOLOCK, INDEX=IX_custid)
				INNER JOIN @SportBettype AS sbt ON b.Bettype = sbt.Bettype
			WHERE
				b.winlostdate BETWEEN @fromdate AND @TempToDate 
				AND b.custid = @custid 
				AND b.recommend = @Recommend 
				AND sbt.ProductID = 1 
				AND sbt.EventType = 0 
				AND b.matchid IN (0, 9, 29) --should not remove 0 in Archive
				AND b.statusID IN (111, 112, 113)
				AND b.transid NOT IN (SELECT Transid FROM #TempBetList)

			-- Outright
			INSERT INTO #BetListByDateMem
			SELECT
				l.sporttype,
				@Username, 
				b.TransID,
				ISNULL(b.BetID,0),
				b.Bettype,
				CONVERT(FLOAT, b.hdp1) AS hdp1, 
				CONVERT(FLOAT, b.hdp2) AS hdp2, 
				0 AS OddsType,
				b.Odds, 
				b.modds,
				b.stake,
				b.actual_stake, 
				'' AS Betteam,
				b.Status,
				b.refno,
				b.Transdate,
				b.winlostdate,
				(b.winlost-actual_stake),
				ABS(b.winlost-actual_stake),
				- (b.winlost-b.actual_stake) AS LicenseeWL,
				b.comm,
				b.playercomm,
				0 AS LiveIndicator, 
				b.LiveHomescore, 
				b.LiveAwayscore,
				b.IP,
				m.LeagueID,
				m.orid, --MatchID
				m.MatchCode,
				m.GroupMatch,--Race
				m.teamID, --HomeID
				0, --AwayID
				0, --Betstatus
				CONVERT(BIT,0) AS IsNeutral,
				b.currency,
				'' AS ShowTime,
				'' AS betcheck,
				'' AS transdesc
			FROM
				bodb_archive.dbo.bettrans_bk AS b WITH (NOLOCK, INDEX=IX_custid)
				INNER JOIN bodb_archive.dbo.Outright_bk AS m WITH (NOLOCK) ON b.matchid = m.orid 
				INNER JOIN dbo.league AS l WITH (NOLOCK) ON m.leagueID = l.leagueID
				INNER JOIN @SportBettype AS sbt ON b.Bettype = sbt.Bettype
			WHERE
				b.winlostdate BETWEEN @fromdate AND @TempToDate 
				AND b.custid = @custid 
				AND b.recommend = @Recommend
				AND sbt.ProductID = 1 
				AND sbt.EventType = 2 
				AND b.statusID IN (111, 112, 113)
				AND b.transid NOT IN (SELECT Transid FROM #TempBetList) 
		END
	
		-- BetTrade
		IF @ShowBT = 1
		BEGIN
			INSERT INTO #BetListByDateMem
			SELECT
				m.Sporttype, 
				@Username, 
				b.TransID,
				ISNULL(ob.bettype,0),
				b.Bettype,
				b.hdp1, 
				b.hdp2,
				b.Oddstype,
				ob.odds,
				b.modds,
				ob.stake,
				b.actual_stake, 
				b.betteam,
				b.status,
				b.refno,
				b.Transdate,
				b.winlostdate,
				(b.winlost-b.actual_stake),
				ABS(b.winlost-b.actual_stake),
				- (b.winlost-b.actual_stake) AS LicenseeWL,
				CASE WHEN b.bettype = 903 THEN b.awinlost ELSE b.comm END AS comm,
				b.playercomm,
				b.Liveindicator,
				b.Livehomescore,
				b.Liveawayscore,
				b.IP,
				m.LeagueID,
				m.MatchID,
				m.MatchCode,
				'' AS Race,
				m.HomeID,
				m.AwayID,
				m.Betstatus,
				ISNULL(m.isNeutral, CONVERT(BIT,0)) AS IsNeutral,
				b.currency,
				'' AS ShowTime,
				b.betcheck,
				'' AS transdesc
			FROM
				bodb_archive.dbo.bettrans_bk AS b WITH (NOLOCK, INDEX=IX_custid)
				INNER JOIN bodb_archive.dbo.bettrans_bk AS ob WITH (NOLOCK) ON b.refno = ob.transid
				INNER JOIN bodb_archive.dbo.match_BK AS m WITH (NOLOCK) ON b.matchid = m.matchid
				INNER JOIN @SportBettype AS sbt ON b.Bettype = sbt.Bettype
			WHERE
				b.winlostdate BETWEEN @fromdate AND @TempToDate 
				AND b.custid = @custid 
				AND b.recommend = @Recommend 
				AND b.statusID IN (111, 112, 113)
				AND sbt.ProductID = 1 
				AND sbt.EventType = 1 
				AND b.bettype IN (901, 902, 903)
		END

		-- Horse Racing
		IF @ShowRB = 1
		BEGIN
			INSERT INTO #BetListByDateMem
			SELECT
				l.sporttype,
				@Username, 
				b.TransID,
				ISNULL(b.BetID,0),
				b.Bettype,
				b.hdp1, 
				b.hdp2,
				0 AS OddsType, 
				b.Odds, 
				b.modds,
				b.stake,
				b.actual_stake, 
				'' AS Betteam,
				b.Status,
				b.refno,
				b.Transdate,
				b.winlostdate,
				(b.winlost-actual_stake),
				ABS(b.winlost-actual_stake),
				b.awinlost,
				b.comm,
				b.playercomm,
				0 AS LiveIndicator,
				b.LiveHomescore,
				b.LiveAwayscore,
				b.IP,
				m.LeagueID,
				m.orid, --MatchID
				m.MatchCode,
				m.GroupMatch,--Race
				m.teamID, --HomeID
				0, --AwayID
				0, --Betstatus
				CONVERT(BIT,0) AS IsNeutral,
				b.currency,
				'' AS ShowTime,
				'' AS betcheck,
				'' AS transdesc
			FROM
				bodb_archive.dbo.bettrans_bk AS b WITH (NOLOCK, INDEX=IX_custid)
				INNER JOIN bodb_archive.dbo.Outright_bk AS m WITH (NOLOCK) ON b.matchid = m.orid 
				INNER JOIN dbo.league AS l WITH (NOLOCK) ON m.leagueID = l.leagueID
				INNER JOIN @SportBettype AS sbt ON b.Bettype = sbt.Bettype
			WHERE
				b.winlostdate BETWEEN @fromdate AND @TempToDate 
				AND b.custid = @custid 
				AND b.recommend = @Recommend 
				AND b.statusID IN (111, 112, 113)
				AND sbt.ProductID = 2 
		END

		-- Number Game, Live Casino
		IF @ShowNG = 1 OR @ShowLC = 1
		BEGIN
			INSERT INTO #BetListByDateMem
			SELECT
				m.Sporttype, 
				@Username, 
				b.TransID,
				ISNULL(b.BetID,0),
				b.Bettype,
				CONVERT(FLOAT, b.hdp1) AS hdp1, 
				CONVERT(FLOAT, b.hdp2) AS hdp2,
				b.OddsType,
				b.Odds,
				b.modds,
				b.stake,
				b.actual_stake, 
				b.Betteam,
				b.status,
				b.refno,
				b.Transdate,
				b.winlostdate,
				(b.winlost-actual_stake),
				ABS(b.winlost-actual_stake),
				- (b.winlost-b.actual_stake) AS LicenseeWL,
				b.comm,
				b.playercomm,
				b.Liveindicator,
				b.Livehomescore,
				b.Liveawayscore,
				b.IP,
				m.LeagueID,
				m.MatchID,
				m.MatchCode,
				'' AS Race,
				m.HomeID,
				m.AwayID,
				m.Betstatus,
				CONVERT(BIT,0) AS IsNeutral,
				b.currency,
				CASE WHEN sbt.ProductID=4 THEN ISNULL(m.showtime,'') ELSE '' END AS ShowTime,
				'' AS betcheck,
				'' AS transdesc
			FROM
				bodb_archive.dbo.bettrans_bk AS b WITH (NOLOCK, INDEX=IX_custid)
				INNER JOIN bodb_archive.dbo.match_bk AS m WITH (NOLOCK) ON b.matchid = m.matchid
				INNER JOIN @SportBettype AS sbt ON b.Bettype = sbt.Bettype
			WHERE
				b.winlostdate BETWEEN @fromdate AND @TempToDate 
				AND b.custid = @CustID 
				AND b.recommend = @Recommend 
				AND sbt.ProductID IN (3, 4)
				AND b.statusID IN (111, 112, 113)
		END
	
		-- Virtual Sports
		IF @ShowVS = 1
		BEGIN
			INSERT INTO #BetListByDateMem
			SELECT
				m.Sporttype, 
				@Username, 
				b.TransID,
				ISNULL(b.BetID,0),
				b.Bettype,
				CONVERT(FLOAT, b.hdp1) AS hdp1, 
				CONVERT(FLOAT, b.hdp2) AS hdp2,
				b.OddsType,
				b.Odds,
				b.modds,
				b.stake,
				b.actual_stake, 
				b.Betteam,
				b.status,
				b.refno,
				b.Transdate,
				b.winlostdate,
				(b.winlost-actual_stake),
				ABS(b.winlost-actual_stake),
				- (b.winlost-b.actual_stake) AS LicenseeWL,
				b.comm,
				b.playercomm,
				b.Liveindicator,
				b.Livehomescore,
				b.Liveawayscore,
				b.IP,
				m.LeagueID,
				m.MatchID,
				m.MatchCode,
				'' AS Race,
				m.HomeID,
				m.AwayID,
				m.Betstatus,
				CONVERT(BIT,0) AS IsNeutral	,
				b.currency,
				'' AS ShowTime,
				'' AS betcheck,
				'' AS transdesc
			FROM
				bodb_archive.dbo.bettrans_bk AS b WITH (NOLOCK, INDEX=IX_custid)
				INNER JOIN bodb_archive.dbo.match_bk AS m WITH (NOLOCK) ON b.matchid = m.matchid
				INNER JOIN @SportBettype AS sbt ON b.Bettype = sbt.Bettype
			WHERE
				b.winlostdate BETWEEN @fromdate AND @TempToDate 
				AND b.custid = @CustID 
				AND b.recommend = @Recommend
				AND sbt.ProductID = 5 
				AND sbt.EventType = 1
				AND b.statusID IN (111, 112, 113)
			
			UNION ALL 

			SELECT
				r.Sporttype, 
				@Username, 
				b.TransID,
				ISNULL(b.BetID,0),
				b.Bettype,
				CONVERT(FLOAT, b.hdp1) AS hdp1, 
				CONVERT(FLOAT, b.hdp2) AS hdp2,
				b.Oddstype,
				b.Odds,
				b.modds,
				b.stake,
				b.actual_stake, 
				b.betteam,
				b.status,
				b.refno,
				b.Transdate,
				b.winlostdate,
				(b.winlost-actual_stake),
				ABS(b.winlost-actual_stake),
				- (b.winlost-b.actual_stake) AS LicenseeWL,
				b.comm,
				b.playercomm,
				b.Liveindicator,
				b.Livehomescore,
				b.Liveawayscore,
				b.IP,
				r.LeagueID,
				o.EventID matchid,
				CONVERT(VARCHAR(50),o.RacerNum) MatchCode,
				b.oddsid AS Race,
				o.RacerID HomeID,
				0 AwayID,
				r.Betstatus,
				CONVERT(BIT,0) AS IsNeutral,
				b.currency,
				CONVERT(VARCHAR(20),r.EventTime) AS ShowTime,
				'' AS betcheck,
				'' AS transdesc
			FROM
				bodb_Archive.dbo.bettrans_bk AS b WITH (NOLOCK,INDEX(IX_custid))
				INNER JOIN bodb_Archive.dbo.VSOutright_bk AS o WITH (NOLOCK) ON b.oddsid = o.Orid
				INNER JOIN dbo.VSRaceInfo AS r WITH (NOLOCK) ON r.EventID = o.EventID	
				INNER JOIN @SportBettype sbt ON b.Bettype = sbt.Bettype	
			WHERE
				b.winlostdate BETWEEN @fromdate AND @TempToDate 
				AND b.recommend = @Recommend --to improve performance
				AND b.custid = @CustID 
				AND sbt.ProductID = 5 
				AND sbt.EventType = 3
				AND b.statusID IN (111, 112, 113)
		END

		-- RNG Casino, Microgaming Live Casino, Microgaming RNG Casino, AG Casino, AllBet, Macau Games. Fishing World
		IF @ShowCS = 1 OR @ShowMGCLC = 1 OR @ShowMGCRNG = 1 OR @ShowAGC = 1 OR @ShowAB = 1 OR @ShowVB = 1 OR @ShowFW = 1
		BEGIN
			INSERT INTO #BetListByDateMem
			SELECT
				CASE
					WHEN sbt.ProductID = 6 AND sbt.SubProduct = '' THEN 251
					WHEN sbt.ProductID = 6 AND sbt.SubProduct <> '' THEN b.matchid
					WHEN sbt.ProductID = 11 THEN 250
					WHEN sbt.ProductID = 13 THEN 203
					WHEN sbt.ProductID = 17 THEN 205
					WHEN sbt.ProductID = 21 THEN 211
					WHEN sbt.ProductID = 22 THEN 212
					WHEN sbt.ProductID = 24 THEN 219
				END AS Sporttype,
				@Username, 
				b.TransID,
				ISNULL(b.BetID, 0),
				b.Bettype,
				CASE
					WHEN sbt.ProductID = 6 AND sbt.SubProduct = '' THEN b.hdp1
					ELSE 0
				END AS hdp1,
				CASE
					WHEN sbt.ProductID = 6 AND sbt.SubProduct = '' THEN b.hdp2
					ELSE 0
				END AS hdp2,
				CASE
					WHEN sbt.ProductID = 6 AND sbt.SubProduct = '' THEN b.oddstype
					ELSE 0
				END AS Oddstype,
				CASE
					WHEN sbt.ProductID = 6 AND sbt.SubProduct = '' THEN b.Odds
					ELSE 0
				END AS Odds,
				CASE
					WHEN sbt.ProductID = 6 AND sbt.SubProduct = '' THEN b.modds
					ELSE 0
				END AS modds,
				b.stake,
				b.actual_stake,
				CASE
					WHEN sbt.ProductID = 6 AND sbt.SubProduct = '' THEN b.Betteam
					ELSE ''
				END AS Betteam,
				b.status,
				b.refno,
				b.Transdate,
				b.winlostdate,
				(b.winlost - actual_stake) AS WinLost,
				ABS(b.winlost - actual_stake) AS BetEffective,
				- (b.winlost - b.actual_stake) AS LicenseeWL,
				b.comm,
				b.playercomm,
				b.Liveindicator,
				b.Livehomescore,
				b.Liveawayscore,
				b.IP,
				0 AS LeagueID,
				CASE
					WHEN sbt.ProductID = 6 AND sbt.SubProduct = '' THEN b.bettype
					ELSE 0
				END AS MatchID,
				'' AS MatchCode,
				'' AS Race,
				0 AS HomeID,
				0 AS AwayID,
				0 AS Betstatus,
				CONVERT(BIT, 0) AS IsNeutral,
				b.currency,
				'' AS ShowTime,
				CASE
					WHEN sbt.ProductID = 13 THEN b.betcheck
					ELSE ''
				END AS betcheck,
				CASE
					WHEN sbt.ProductID = 6 AND sbt.SubProduct <> '' THEN b.transdesc
					WHEN sbt.ProductID IN (22, 24) THEN b.transdesc
					ELSE ''
				END AS transdesc
			FROM
				bodb_archive.dbo.bettrans_bk AS b WITH (NOLOCK, INDEX=IX_custid)
				INNER JOIN @SportBettype AS sbt ON b.Bettype = sbt.Bettype
			WHERE
				b.winlostdate BETWEEN @fromdate AND @TempToDate 
				AND b.custid = @CustID 
				AND b.recommend = @Recommend 
				AND sbt.ProductID IN (6, 11, 13, 17, 21, 22, 24)
				AND sbt.EventType = 0 
				AND b.statusID IN (111, 112, 113)
		END

		-- Show Keno
		IF @ShowKN = 1
		BEGIN
			INSERT INTO #BetListByDateMem
			SELECT
				202 Sporttype, 
				@Username, 
				b.TransID,
				ISNULL(b.BetID,0),
				b.Bettype,
				0 AS hdp1, 
				0 AS hdp2,
				b.OddsType,
				b.Odds,
				b.modds,
				b.stake,
				b.actual_stake, 
				ChoiceID Betteam,
				b.status,
				b.refno,
				b.Transdate,
				b.winlostdate,
				(b.winlost-actual_stake),
				ABS(b.winlost-actual_stake),
				- (b.winlost-b.actual_stake) AS LicenseeWL,
				b.comm,
				b.playercomm,
				b.Liveindicator,
				b.Livehomescore,
				b.Liveawayscore,
				b.IP,
				0 AS LeagueID,
				GameId AS MatchID,
				'' AS MatchCode,
				'' AS Race,
				0 AS HomeID,
				0 AS AwayID,
				0 AS Betstatus,
				CONVERT(BIT,0) AS IsNeutral,
				b.currency,
				'' AS ShowTime,
				'' AS betcheck,
				'' AS transdesc
			FROM
				bodb_archive.dbo.bettrans_bk AS b WITH (NOLOCK, INDEX=IX_custid)
				CROSS APPLY dbo.f_ParseTransDesc(b.transdesc, b.bettype)
				INNER JOIN @SportBettype AS sbt ON b.Bettype = sbt.Bettype
			WHERE
				b.winlostdate BETWEEN @fromdate AND @TempToDate 
				AND b.custid = @CustID 
				AND b.recommend = @Recommend 
				AND sbt.ProductID = 8 
				AND sbt.EventType = 0 
				AND b.statusID IN (111, 112, 113)
		END
	END

	IF @ShowBT = 1
	BEGIN
		UPDATE betList
		SET betList.comm = CASE WHEN betList.Bettype = 902 THEN commBetList.comm ELSE betList.comm END
		FROM #BetListByDateMem AS betList
			INNER JOIN #BetListByDateMem AS commBetList ON betList.RefNO = commBetList.RefNO
		WHERE betList.Sporttype = 1 
			AND betList.Bettype IN (901, 902)
			AND commBetList.Bettype = 903

		DELETE #BetListByDateMem WHERE Sporttype = 1 AND Bettype = 903
	END

	DECLARE @RowStart INT, @RowEnd INT

	SELECT @PageIndex = @PageIndex - 1, 
		@RowStart = @PageSize * @PageIndex + 1,
		@RowEnd = @RowStart + @PageSize - 1

	CREATE NONCLUSTERED INDEX IDX_Index_betlist ON #BetListByDateMem (Currency)

	IF @CurrencyID <> 0
	BEGIN 
		DELETE #BetListByDateMem
		WHERE Currency <> @CurrencyID
	END

	SELECT * INTO #TempExchange 
	FROM Lrf_f_GetExchangeDaily(@FromDate,@ToDate)
	WHERE exchangeid IN (SELECT DISTINCT Currency FROM #BetListByDateMem)

	UPDATE #BetListByDateMem
	SET BetEffective = 0
	WHERE winlostdate < @BetEffectiveDate
		OR status NOT IN ('LOSE','WON')

	SELECT
		@TotalRows = COUNT(transid),
		@SumWinlost			= SUM(ISNULL(b.WinLost, 0)),
		@SumBetEffective	= SUM(ISNULL(b.BetEffective, 0)),
		@SumLicenseeWL		= SUM(ISNULL(b.LicenseeWL, 0)),
		@SumComm			= SUM(ISNULL(b.Comm, 0)),
		@SumPlayerComm		= SUM(ISNULL(b.PlayerComm, 0)),
		--USD
		@SumWinlostUSD		= SUM(ISNULL(b.WinLost		* e.USD, 0)),
		@SumBetEffectiveUSD	= SUM(ISNULL(b.BetEffective	* e.USD, 0)),
		@SumLicenseeWLUSD	= SUM(ISNULL(b.LicenseeWL	* e.USD, 0)),
		@SumCommUSD			= SUM(ISNULL(b.Comm			* e.USD, 0)),
		@SumPlayerCommUSD	= SUM(ISNULL(b.PlayerComm	* e.USD, 0)),
		--EUR
		@SumWinlostEUR		= SUM(ISNULL(b.WinLost		* e.EUR, 0)),
		@SumBetEffectiveEUR	= SUM(ISNULL(b.BetEffective	* e.EUR, 0)),
		@SumLicenseeWLEUR	= SUM(ISNULL(b.LicenseeWL	* e.EUR, 0)),
		@SumCommEUR			= SUM(ISNULL(b.Comm			* e.EUR, 0)),
		@SumPlayerCommEUR	= SUM(ISNULL(b.PlayerComm	* e.EUR, 0)),
		--GBP
		@SumWinlostGBP		= SUM(ISNULL(b.WinLost		* e.GBP, 0)),
		@SumBetEffectiveGBP	= SUM(ISNULL(b.BetEffective	* e.GBP, 0)),
		@SumLicenseeWLGBP	= SUM(ISNULL(b.LicenseeWL	* e.GBP, 0)),
		@SumCommGBP			= SUM(ISNULL(b.Comm			* e.GBP, 0)),
		@SumPlayerCommGBP	= SUM(ISNULL(b.PlayerComm	* e.GBP, 0))
	FROM #BetListByDateMem AS b
		INNER JOIN #TempExchange AS e
			ON e.ExchangeDate = (CASE WHEN b.winlostdate <= @Today THEN b.winlostdate ELSE @Today END) AND e.exchangeid = b.currency

	SELECT A.*
	FROM
	(
		SELECT
			ROW_NUMBER() OVER(ORDER BY b.TransId) AS RowNum,
			b.*,
			-- USD
			b.Stake			* e.USD AS StakeUSD,
			b.Actual_Stake	* e.USD AS Actual_StakeUSD,
			b.WinLost		* e.USD AS WinLostUSD,
			b.BetEffective	* e.USD AS BetEffectiveUSD,
			b.LicenseeWL	* e.USD AS LicenseeWLUSD,
			b.Comm			* e.USD AS CommUSD,
			b.PlayerComm	* e.USD AS PlayerCommUSD,
			-- EUR
			b.Stake			* e.EUR AS StakeEUR,
			b.Actual_Stake	* e.EUR AS Actual_StakeEUR,
			b.WinLost		* e.EUR AS WinLostEUR,
			b.BetEffective	* e.EUR AS BetEffectiveEUR,
			b.LicenseeWL	* e.EUR AS LicenseeWLEUR,
			b.Comm			* e.EUR AS CommEUR,
			b.PlayerComm	* e.EUR AS PlayerCommEUR,
			-- GBP
			b.Stake			* e.GBP AS StakeGBP,
			b.Actual_Stake	* e.GBP AS Actual_StakeGBP,
			b.WinLost		* e.GBP AS WinLostGBP,
			b.BetEffective	* e.GBP AS BetEffectiveGBP,
			b.LicenseeWL	* e.GBP AS LicenseeWLGBP,
			b.Comm			* e.GBP AS CommGBP,
			b.PlayerComm	* e.GBP AS PlayerCommGBP
		FROM #BetListByDateMem AS b
			INNER JOIN #TempExchange AS e
				ON e.ExchangeDate = (CASE WHEN b.winlostdate <= @Today THEN b.winlostdate ELSE @Today END) AND e.exchangeid = b.currency
	) A WHERE A.RowNum BETWEEN @RowStart AND @RowEnd

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

	-- Horse Racing
	IF EXISTS (	SELECT 1
				FROM #BetListByDateMem AS b
					INNER JOIN @SportBettype AS sbt ON b.BetType = sbt.Bettype
				WHERE sbt.ProductID = 2)
	BEGIN
		IF @Todate > @MoveBetsDay
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
				INNER JOIN #BetListByDateMem AS b ON bm.refno = b.TransId
				INNER JOIN #TempExchange AS e ON e.ExchangeDate = b.WinLostDate AND e.exchangeid = b.currency
				INNER JOIN @SportBettype AS sbt ON b.bettype = sbt.bettype
				INNER JOIN @SportBettype AS sbtm ON bm.bettype = sbtm.Bettype
			WHERE bm.custid = @CustId
				AND sbt.ProductID = 2
				AND sbtm.ProductID = 2
		END

		IF @Fromdate <= @MoveBetsDay AND @ToDate >= @BalanceUpDay
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
				INNER JOIN #BetListByDateMem AS b ON bm.refno = b.transid
				INNER JOIN #TempExchange AS e ON e.ExchangeDate = b.winlostdate AND e.exchangeid = b.currency
				INNER JOIN @SportBettype AS sbt ON b.bettype = sbt.bettype
				INNER JOIN @SportBettype AS sbtm ON bm.bettype = sbtm.Bettype
			WHERE bm.custid = @CustId
				AND sbt.ProductID = 2
				AND sbtm.ProductID = 2
		END

		IF @FromDate < @BalanceUpDay
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
			FROM bodb_Archive.dbo.bettransm AS bm WITH (NOLOCK)
				INNER JOIN #BetListByDateMem AS b ON bm.refno = b.transid
				INNER JOIN #TempExchange AS e ON e.ExchangeDate = b.winlostdate AND e.exchangeid = b.currency
				INNER JOIN @SportBettype AS sbt ON b.bettype = sbt.bettype
				INNER JOIN @SportBettype AS sbtm ON bm.bettype = sbtm.Bettype
			WHERE bm.custid = @CustId
				AND sbt.ProductID = 2
				AND sbtm.ProductID = 2
		END
	END

	-- Live Casino
	IF EXISTS (	SELECT 1
				FROM #BetListByDateMem AS b
					INNER JOIN @SportBettype AS sbt ON b.BetType = sbt.Bettype
				WHERE sbt.ProductId = 4 )
	BEGIN
		IF @Todate > @MoveBetsDay
		BEGIN
			INSERT INTO @BettransDetail
			SELECT
				bg.refno,
				bg.odds,
				bg.stake,
				bg.status,
				bg.apositiontaking,
				bg.bettype,
				bg.betteam,
				bg.stake * e.EUR,
				bg.stake * e.USD,
				bg.stake * e.GBP
			FROM dbo.bettransg AS bg WITH (NOLOCK)
				INNER JOIN #BetListByDateMem AS b ON bg.refno = b.RefNo
				INNER JOIN #TempExchange AS e ON e.ExchangeDate = b.WinLostDate AND e.exchangeid = b.Currency
				INNER JOIN @SportBettype AS sbt ON b.BetType = sbt.bettype
				INNER JOIN @SportBettype AS sbtg ON bg.bettype = sbtg.bettype
			WHERE bg.custid = @CustId
				AND sbt.ProductID = 4
				AND sbtg.ProductID = 4
		END

		IF @Fromdate <= @MoveBetsDay AND @ToDate >= @BalanceUpDay
		BEGIN
			INSERT INTO @BettransDetail
			SELECT 
				bg.refno,
				bg.odds,
				bg.stake,
				bg.status,
				bg.apositiontaking,
				bg.bettype,
				bg.betteam,
				bg.stake * e.EUR,
				bg.stake * e.USD,
				bg.stake * e.GBP
			FROM dbo.bettransg14 AS bg WITH (NOLOCK)
				INNER JOIN #BetListByDateMem AS b ON bg.refno = b.RefNo
				INNER JOIN #TempExchange AS e ON e.ExchangeDate = b.WinLostDate AND e.exchangeid = b.currency
				INNER JOIN @SportBettype AS sbt ON b.BetType = sbt.bettype
				INNER JOIN @SportBettype AS sbtg ON bg.bettype = sbtg.bettype
			WHERE bg.custid = @CustId
				AND sbt.ProductID = 4
				AND sbtg.ProductID = 4
		END

		IF @FromDate < @BalanceUpDay
		BEGIN
			INSERT INTO @BettransDetail
			SELECT
				bg.refno,
				bg.odds,
				bg.stake,
				bg.status,
				bg.apositiontaking,
				bg.bettype,
				bg.betteam,
				bg.stake * e.EUR,
				bg.stake * e.USD,
				bg.stake * e.GBP
			FROM bodb_archive.dbo.bettransg AS bg WITH (NOLOCK)
				INNER JOIN #BetListByDateMem AS b ON bg.refno = b.RefNo
				INNER JOIN #TempExchange AS e ON e.ExchangeDate = b.WinLostDate AND e.exchangeid = b.currency
				INNER JOIN @SportBettype AS sbt ON b.BetType = sbt.bettype
				INNER JOIN @SportBettype AS sbtg ON bg.bettype = sbtg.bettype
			WHERE bg.custid = @CustId
				AND sbt.ProductID = 4
				AND sbtg.ProductID = 4
		END
	END

	-- Virtual Sports
	IF EXISTS (	SELECT 1
				FROM #BetListByDateMem AS b
					INNER JOIN @SportBettype AS sbt ON b.bettype = sbt.Bettype
				WHERE sbt.ProductId = 5 AND sbt.EventType = 3)
	BEGIN 
		IF @Todate > @MoveBetsDay
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
				INNER JOIN #BetListByDateMem AS b ON bm.refno = b.RefNo
				INNER JOIN #TempExchange AS e ON e.ExchangeDate = b.WinLostDate AND e.exchangeid = b.currency
				INNER JOIN @SportBettype AS sbt ON b.bettype = sbt.bettype
				INNER JOIN @SportBettype AS sbtm ON bm.bettype = sbtm.Bettype
			WHERE bm.custid = @CustId
				AND sbt.ProductId = 5
				AND sbt.EventType = 3
				AND sbtm.ProductId = 5
				AND sbtm.EventType = 3
		END

		IF @FromDate <= @MoveBetsDay AND @ToDate >= @BalanceUpDay
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
				INNER JOIN #BetListByDateMem AS b ON bm.refno = b.RefNo
				INNER JOIN #TempExchange AS e ON e.ExchangeDate = b.WinLostDate AND e.exchangeid = b.currency
				INNER JOIN @SportBettype AS sbt ON b.bettype = sbt.bettype
				INNER JOIN @SportBettype AS sbtm ON bm.bettype = sbtm.Bettype
			WHERE bm.custid = @CustId
				AND sbt.ProductId = 5
				AND sbt.EventType = 3
				AND sbtm.ProductId = 5
				AND sbtm.EventType = 3
		END

		IF @FromDate < @BalanceUpDay
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
			FROM bodb_archive.dbo.bettransm AS bm WITH (NOLOCK)
				INNER JOIN #BetListByDateMem AS b ON bm.refno = b.RefNo
				INNER JOIN #TempExchange AS e ON e.ExchangeDate = b.WinLostDate AND e.exchangeid = b.currency
				INNER JOIN @SportBettype AS sbt ON b.bettype = sbt.bettype
				INNER JOIN @SportBettype AS sbtm ON bm.bettype = sbtm.Bettype
			WHERE bm.custid = @CustId
				AND sbt.ProductId = 5
				AND sbt.EventType = 3
				AND sbtm.ProductId = 5
				AND sbtm.EventType = 3
		END
	END

	SELECT * FROM @BettransDetail 
	ORDER BY RefNo, Bettype 

	DROP TABLE #TempExchange
	DROP TABLE #BetListByDateMem
	DROP TABLE #TempBetList
END





GO
GRANT EXECUTE ON [dbo].[Lrf_BetList_SelWinLossByDate_Mem] TO [bodbLicenseeNet] AS [dbo]
GO
GRANT VIEW DEFINITION ON [dbo].[Lrf_BetList_SelWinLossByDate_Mem] TO [vnteam] AS [dbo]