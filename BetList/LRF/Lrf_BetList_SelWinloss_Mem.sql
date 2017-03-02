USE [bodb02]
GO
 
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
ALTER PROCEDURE [dbo].[Lrf_BetList_SelWinloss_Mem]
	@LicenseeId			INT,
	@UserId				INT,
	@CustId				INT,
	@FromDate			DATETIME,
	@ToDate				DATETIME,
	@MoveBetsDay		SMALLDATETIME,
	@BalanceUpDay		SMALLDATETIME,
	@ShowSB				BIT			= 0,
	@ShowRB				BIT			= 0,
	@ShowNG				BIT			= 0,
	@ShowBA				BIT			= 0,
	@ShowLC				BIT			= 0,
	@ShowVS				BIT			= 0,
	@ShowCS				BIT			= 0,	-- RNG Casino
	@ShowKN				BIT			= 0,	-- Keno
	@ShowMGCLC			BIT			= 0,	-- Microgaming Live Casino
	@ShowMGCRNG			BIT			= 0,	-- Microgaming RNG Casino
	@ShowAGC			BIT			= 0,	-- AG Casino
	@ShowAB				BIT			= 0,	-- AllBet
	@ShowVB				BIT			= 0,	-- Voidbridge
	@ShowCB				BIT			= 0,	-- Colossus Bets
	@ShowFW				BIT			= 0,	-- Fishing World
	@ShowBT				BIT			= 0,	-- Bet Trade
	@PageSize			INT			= 1000,
	@PageIndex			INT			= 1,
	@TotalRows			INT			= 0 OUTPUT,
	@SumWinLost			MONEY		= 0 OUTPUT,
	@SumWinLostUSD		MONEY		= 0 OUTPUT,
	@SumWinLostEUR		MONEY		= 0 OUTPUT,
	@SumWinLostGBP		MONEY		= 0 OUTPUT,
	@SumLicenseeWL		MONEY		= 0 OUTPUT,
	@SumLicenseeWLUSD	MONEY		= 0 OUTPUT,
	@SumLicenseeWLEUR	MONEY		= 0 OUTPUT,
	@SumLicenseeWLGBP	MONEY		= 0 OUTPUT,
	@SumComm			MONEY		= 0 OUTPUT,
	@SumCommUSD			MONEY		= 0 OUTPUT,
	@SumCommEUR			MONEY		= 0 OUTPUT,
	@SumCommGBP			MONEY		= 0 OUTPUT,
	@SumPlayerComm		MONEY		= 0 OUTPUT,
	@SumPlayerCommUSD	MONEY		= 0 OUTPUT,
	@SumPLayerCommEUR	MONEY		= 0 OUTPUT,
	@SumPLayerCommGBP	MONEY		= 0 OUTPUT,
	@DrawFilter			SMALLINT	= 1,
	@LangKey			VARCHAR(10) = 'en-US',
	@CurrencyId			INT			= 0 
AS

/*
	Created: Henry
	Date: 2012-01-09
	Task : Betlist for Licensee Winloss Report
	DB: DBACC.bodb02

	Revisions:
		- 20120214@Jim: change table ExchangeDaily by function Lrf_f_GetExchangeDaily
		- 20120319@Henry: show main transid for sub-ticket of system parlay 
		- 20120529@Henry: enhance performance
		- 20120703@Henry: add value to column hdp1, hdp2 for Number Game
		- 20120717@Jim: add paging filter
		- 20120723@Jim: add playercomm value 
		- 20120816@Henry: add ShowLiveCasino 
		- 20120911@Jim : add virtual sport
		- 20130123@Daniel: Change link server alias
		- 20130204@Jim: support RNG Casino and Bingo product
		- 20130514@Jim:Restrict permission of Licensee Users by currency
		- 20130716@Jim: update matchid for RNG Casino and Bingo
		- 20130809@Jim: offer Virtual Horse Racing
		- 20140307@Hannah: offer Keno
		- 20140630@Hannah: offer BetRadar and Sporting Solution
		- 20140908@Jim: restrict Virtual Horse Racing bettype (hot fix  #22012)
		- 20141128@winnie: change currency keenocean	
		- 20150124@winnie: Add base currency GBP
		- 20150406@Winnie: Add 60 bettypes Betradar & Apply matrix of sporttype & bettype 
		- 20150515@Winnie: fix bug
		- 20150604@Edward: Support Microgaming
		- 20150608@Edward: Support Bet Trade
		- 20150729@Edward: Return betcheck for Microgaming
		- 20150828@Edward: Fixed Odds value of ticket 901, 902 is displayed incorrectly
		- 20150914@Kos: Support Microgaming RNG Casino
		- 20150922@Kos: Support AG Casino
		- 20151030@Kos: Change ProductId/SportType of Microgaming RNG Casino
		- 20151203@Kos: Change odds, modds data type from SMALLMONEY to MONEY [Redmine: #48660]
		- 20151224@Jim: Fix bug [Redmine: #49885]
		- 20151225@Kos: Support RNG Casino Single Wallet [Redmine: #48958]
		- 20160201@Kos: Support PH All In One 1.2 [#Redmine: 50897]
		- 20160216@Kos: Support yesterday running ticket [Redmine: #52277]
		- 20160405@Kos: Support Voidbridge [#Redmine: 54925]
		- 20160412@Kos: Support Combo Parlay [#Redmine: 55282]
		- 20160714@Kos: Remove Bingo code and change to use inline function for SportBettypeMatrix
		- 20160726@Kos: Support AllBet [#Redmine: 61066]
		- 20160801@Kos: Exclude bet type 904 [#Redmine: 58978]
		- 20160913@Kos: Support Colossus Bets [#Redmine: 63785]
		- 20161004@Kos: Add product bet type range for sub tickets [Redmine: #65045]
		- 20161111@Kos: Support Fishing World [#Redmine: 66737]
		- 20161205@Kos: Fix Colossus Bets bet list empty before BalanceUpDay [Redmine: #68289]
		- 20170302@Kos: Support KickOffTime for Virtual Soccer and Virtual Tennis [#Redmine: 71906]

	Param's Explanation:
		+ @DrawFilter: 'No Draw' filter is supportted
			- 1: Normal
			- 2: No Draw
			- 3: No Draw for Turnover only
*/

BEGIN
	SET NOCOUNT ON

	DECLARE @fdate DATETIME,
		@tdate DATETIME

	SELECT @fdate = @FromDate,
		@tdate = @ToDate

	DECLARE @BetListByDateMem AS TABLE (
		SportType		INT,
		TransId			BIGINT,
		BetId			BIGINT,
		BetType			INT,
		Hdp1			SMALLMONEY,
		Hdp2			SMALLMONEY,
		MOdds			MONEY,
		OddsType		TINYINT,
		Odds			MONEY,
		Stake			MONEY,
		Actual_Stake	MONEY,
		BetTeam			NVARCHAR(20),
		Status			NVARCHAR(10),
		RefNo			BIGINT,
		TransDate		DATETIME,
		WinLostDate		DATETIME,
		WinLost			MONEY,
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
		VirtualRate		FLOAT,
		IsShowOTExRate	BIT,
		Currency		INT,
		ShowTime		NVARCHAR(50), -- table - shoe - hand of Live Casino
		BetCheck		NVARCHAR(50),
		TransDesc		NVARCHAR(300)
	)

	DECLARE @TempBetList AS TABLE (
		TransId			BIGINT,
		BetId			BIGINT,
		BetType			INT,
		Hdp1			SMALLMONEY,
		Hdp2			SMALLMONEY,
		Modds			MONEY,
		OddsType		TINYINT,
		Odds			MONEY,
		Stake			MONEY,
		Actual_Stake	MONEY,
		BetTeam			NVARCHAR(20),
		Status			NVARCHAR(10),
		RefNo			BIGINT,
		TransDate		DATETIME,
		WinLostDate		DATETIME,
		WinLost			MONEY,
		LicenseeWL		MONEY,
		Comm			MONEY,
		PlayerComm		MONEY,
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

	-- Get Sport Bettype Matrix
	DECLARE @SportBettype TABLE(ProductID TINYINT, Bettype SMALLINT, EventType TINYINT, SubProduct VARCHAR(500))

	DECLARE @IsTest BIT = 0

	SELECT @IsTest = dbo.f_CheckSPVersion(@@PROCID)

	INSERT INTO @SportBettype
	SELECT ProductID, BetType, EventType, SubProduct
	FROM dbo.f_SportBettypeMatrix_Sel (0, 0, 0, 2, '', '', @IsTest)
	WHERE ProductID <= 6 OR ProductID IN (8, 11, 13, 15, 17, 21, 22, 24)

	DELETE FROM @SportBettype
	WHERE ProductID = 1 AND Bettype = 904

	IF @ShowBT = 0
	BEGIN
		DELETE @SportBettype
		WHERE ProductID = 1 AND Bettype IN (901, 902, 903)
	END

	DELETE FROM @SportBettype
	WHERE (ProductID	= CASE WHEN @ShowSB = 0 AND @ShowBA = 0 THEN 1 END AND Bettype NOT IN (901, 902, 903))
		OR ProductID	= CASE WHEN @ShowRB = 0		THEN 2 END
		OR ProductID	= CASE WHEN @ShowNG = 0		THEN 3 END
		OR ProductID	= CASE WHEN @ShowLC = 0		THEN 4 END
		OR ProductID	= CASE WHEN @ShowVS = 0		THEN 5 END
		OR ProductID	= CASE WHEN @ShowCS = 0		THEN 6 END
		OR ProductID	= CASE WHEN @ShowKN = 0		THEN 8 END
		OR ProductID	= CASE WHEN @ShowAGC = 0	THEN 11 END
		OR ProductID	= CASE WHEN @ShowMGCLC = 0	THEN 13 END
		OR ProductID	= CASE WHEN @ShowCB = 0		THEN 15 END
		OR ProductID	= CASE WHEN @ShowMGCRNG = 0	THEN 17 END
		OR ProductID	= CASE WHEN @ShowAB = 0		THEN 21 END
		OR ProductID	= CASE WHEN @ShowVB = 0		THEN 22 END
		OR ProductID	= CASE WHEN @ShowFW = 0		THEN 24 END

	IF @tdate > @MoveBetsDay
	BEGIN
		IF @fdate <= @MoveBetsDay 
			SET @TempFromDate = DATEADD(DAY, 1, @MoveBetsDay)
		ELSE
			SET @TempFromDate = @fdate

		-- Get BA Tickets
		INSERT INTO @TempBetList
		SELECT
			b.TransID,
			ISNULL(b.BetID, 0),
			b.Bettype,
			b.hdp1,
			b.hdp2,
			b.modds,
			b.OddsType,
			b.Odds,
			b.stake,
			b.actual_stake, 
			b.betteam,
			b.status,
			b.refno,
			b.Transdate,
			b.winlostdate,
			(b.winlost-actual_stake),
			0,
			b.comm,
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
			dbo.bettrans AS b WITH (NOLOCK)
			INNER JOIN DBLIC.bodb_Licensee.dbo.LicenseeBATransaction BA WITH (NOLOCK) ON b.transid = BA.transid
		WHERE
			b.winlostdate BETWEEN @TempFromDate AND @tdate
			AND b.custid = @custid
			AND (@currencyID = 0 OR b.currency = @currencyID )
			AND b.statusID IN (111, 112, 113)
			AND b.bettype NOT IN (901, 902, 903)

		IF @ShowBA = 1
		BEGIN
			-- Sportsbook
			INSERT INTO @BetListByDateMem
			SELECT
				m.Sporttype,
				b.TransID,
				b.BetID,
				b.Bettype,
				b.hdp1, 
				b.hdp2,
				b.modds,
				b.oddstype,
				b.odds,
				b.stake,
				b.actual_stake,
				b.betteam,
				b.status,
				b.refno,
				b.Transdate,
				b.winlostdate,
				b.Winlost,
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
				0,
				0,
				b.currency,
				'' AS ShowTime,
				b.betcheck,
				b.transdesc
			FROM
				@TempBetList AS b
				INNER JOIN dbo.match AS m WITH (NOLOCK) ON b.matchid = m.matchid 
				INNER JOIN @SportBettype sbt ON b.Bettype = sbt.Bettype
			WHERE sbt.ProductID = 1 AND sbt.EventType = 1

			-- Outright
			INSERT INTO @BetListByDateMem
			SELECT
				l.sporttype,
				b.TransID,
				b.BetID,
				b.Bettype,
				0 AS hdp1,
				0 AS hdp2,
				b.modds,
				0 AS OddsType,
				b.Odds,
				b.stake,
				b.actual_stake,
				'' AS Betteam,
				b.Status,
				b.refno,
				b.Transdate,
				b.winlostdate,
				b.Winlost,
				b.LicenseeWL,
				b.comm,
				b.playercomm,
				0 AS LiveIndicator, 
				b.LiveHomescore, 
				b.LiveAwayscore,
				b.IP,
				m.LeagueID,
				m.OrId,
				m.MatchCode,
				m.GroupMatch,--Race
				m.TeamID, --HomeID
				0, --AwayID		
				0, --Betstatus
				CONVERT(BIT,0) AS IsNeutral,
				0,
				0,
				b.currency,
				'' AS ShowTime,
				'' AS betcheck,
				'' AS transdesc
			FROM
				@TempBetList AS b
				INNER JOIN dbo.Outright AS m WITH (NOLOCK) ON b.matchid = m.orid
				INNER JOIN dbo.League AS l WITH (NOLOCK) ON m.leagueID = l.leagueID
				INNER JOIN @SportBettype AS sbt ON b.Bettype = sbt.Bettype
			WHERE sbt.ProductID = 1 AND sbt.EventType = 2

			-- Mix Parlay + System Parlay
			INSERT INTO @BetListByDateMem
			SELECT
				0, --Sporttype
				CASE
					WHEN b.bettype <> 29 THEN b.transid
					ELSE CASE WHEN ISNULL(b.BetID,0) = 0 THEN b.transid ELSE betid END
				END AS transid,
				b.BetID,
				b.bettype,
				b.hdp1,
				b.hdp2,
				modds,
				0 AS OddsType, 
				b.Odds,
				b.stake,
				b.actual_stake,
				b.betteam,
				b.Status,
				b.refno,
				b.Transdate,
				b.winlostdate,
				b.Winlost,
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
				0,
				0,
				b.currency,
				'' AS ShowTime,
				ISNULL(b.betcheck, '') AS BetCheck,
				'' AS transdesc
			FROM
				@TempBetList b
				INNER JOIN @SportBettype sbt ON b.Bettype = sbt.Bettype
			WHERE b.matchid IN (9, 29) 
				AND sbt.ProductID = 1 
				AND sbt.EventType = 0
		END

		-- Sportsbook
		IF @ShowSB = 1
		BEGIN
			INSERT INTO @BetListByDateMem
			SELECT
				m.sporttype,
				b.transid,
				ISNULL(b.BetID, 0),
				b.Bettype,
				b.hdp1, 
				b.hdp2,
				modds,
				b.OddsType,
				b.Odds,
				b.stake,
				b.actual_stake,
				b.betteam,
				b.status,
				b.refno,
				b.Transdate,
				b.winlostdate,
				(b.winlost-actual_stake),
				- (b.winlost-actual_stake),
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
				0,
				0,
				b.currency,
				'' AS ShowTime,
				b.betcheck,
				ISNULL(b.transdesc, '') AS transdesc
			FROM
				dbo.bettrans AS b WITH (NOLOCK)
				INNER JOIN dbo.match AS m WITH (NOLOCK) ON b.matchid = m.matchid
				INNER JOIN @SportBettype AS sbt ON b.Bettype = sbt.Bettype
			WHERE
				b.winlostdate BETWEEN @TempFromDate AND @tdate 
				AND b.custid = @custid
				AND (@currencyID = 0 OR b.currency = @currencyID)
				AND b.bettype NOT IN (901, 902, 903)
				AND sbt.ProductID = 1
				AND sbt.EventType = 1
				AND b.matchid > 0
				AND b.statusID IN (111, 112, 113)
				AND b.transid NOT IN (SELECT Transid FROM @TempBetList) --exclude BA tickets

			-- Outright
			INSERT INTO @BetListByDateMem
			SELECT
				l.sporttype,
				b.TransID,
				ISNULL(b.BetID, 0),
				b.Bettype,
				0 AS hdp1, 
				0 AS hdp2, 
				modds,
				0 AS OddsType, 
				b.Odds, 
				b.stake,
				b.actual_stake, 
				'' AS Betteam,
				b.Status,
				b.refno,
				b.Transdate,
				b.winlostdate,
				(b.winlost-actual_stake),
				- (b.winlost-actual_stake),
				b.comm,
				b.playercomm,
				0 AS LiveIndicator,
				b.LiveHomescore,
				b.LiveAwayscore,
				b.IP,
				m.LeagueID,
				m.OrId,
				m.MatchCode,
				m.GroupMatch,--Race
				m.TeamID, --HomeID
				0, --AwayID
				0, --Betstatus
				CONVERT(BIT,0) AS IsNeutral,
				0,
				0,
				b.currency,
				'' AS ShowTime,
				'' AS betcheck,
				'' AS transdesc
			FROM
				dbo.bettrans AS b WITH (NOLOCK)
				INNER JOIN dbo.Outright AS m WITH (NOLOCK) ON b.matchid = m.orid
				INNER JOIN dbo.League AS l WITH (NOLOCK) ON m.leagueID = l.leagueID
				INNER JOIN @SportBettype AS sbt ON b.Bettype = sbt.Bettype
			WHERE
				b.winlostdate BETWEEN @TempFromDate AND @tdate 
				AND b.custid = @custid 
				AND (@currencyID = 0 OR b.currency = @currencyID) 
				AND sbt.ProductID = 1 
				AND sbt.EventType = 2 
				AND b.statusID IN (111, 112, 113) 
				AND b.transid NOT IN (SELECT Transid FROM @TempBetList) --exclude BA tickets

			-- Mix Parlay + System Parlay
			INSERT INTO @BetListByDateMem
			SELECT
				0, --Sporttype
				CASE
					WHEN b.bettype <> 29 THEN b.transid
					ELSE CASE WHEN ISNULL(b.BetID,0) = 0 THEN b.transid ELSE betid END
				END AS transid,	
				ISNULL(b.BetID, 0),
				b.bettype,
				b.hdp1, 
				b.hdp2, 
				modds,
				0 AS OddsType, 
				b.Odds, 
				b.stake,
				b.actual_stake, 
				b.betteam,
				b.Status,
				b.refno,
				b.Transdate,
				b.winlostdate,
				(b.winlost-actual_stake),
				- (b.winlost-actual_stake),
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
				0,
				0,
				b.currency,
				'' AS ShowTime,
				ISNULL(b.betcheck, '') AS BetCheck,
				'' AS transdesc
			FROM
				dbo.bettrans AS b WITH (NOLOCK)
				INNER JOIN @SportBettype AS sbt ON b.Bettype = sbt.Bettype
			WHERE
				b.winlostdate BETWEEN @TempFromDate AND @tdate 
				AND b.custid = @custid 
				AND (@currencyID = 0 OR b.currency = @currencyID) 
				AND sbt.ProductID = 1 
				AND sbt.EventType = 0 
				AND b.matchid IN (9, 29) 
				AND b.statusID IN (111, 112, 113) 
				AND b.transid NOT IN (SELECT Transid FROM @TempBetList) --exclude BA tickets
		END

		-- BetTrade
		IF @ShowBT = 1
		BEGIN
			INSERT INTO @BetListByDateMem
			SELECT
				m.Sporttype,
				b.TransID,
				ISNULL(ob.bettype,0) AS BetID,
				b.Bettype,
				b.hdp1,
				b.hdp2,
				b.modds,
				b.OddsType,
				ob.Odds,
				ob.stake,
				b.actual_stake,
				b.betteam,
				b.status,
				b.refno,
				b.Transdate,
				b.winlostdate,
				(b.winlost-b.actual_stake),
				- (b.winlost-b.actual_stake),
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
				m.Betstatus,
				ISNULL(m.isNeutral, CONVERT(BIT,0)) AS IsNeutral,
				0,
				0,
				b.currency,
				'' AS ShowTime,
				b.betcheck,
				'' AS transdesc
			FROM
				dbo.bettrans AS b WITH (NOLOCK)
				INNER JOIN dbo.bettrans AS ob WITH(NOLOCK) ON b.refno = ob.transid
				INNER JOIN dbo.match AS m WITH (NOLOCK) ON b.matchid = m.matchid
				INNER JOIN @SportBettype AS sbt ON b.Bettype = sbt.Bettype
			WHERE
				b.winlostdate BETWEEN @TempFromDate AND @tdate
				AND b.custid = @custid
				AND (@currencyID = 0 OR b.currency = @currencyID)
				AND b.bettype IN (901, 902, 903)
				AND sbt.ProductID = 1
				AND sbt.EventType = 1
				AND b.matchid > 0
				AND b.statusID IN (111, 112, 113)
		END

		-- Number Game, Live Casino
		IF @ShowNG = 1 OR @ShowLC = 1
		BEGIN
			INSERT INTO @BetListByDateMem
			SELECT
				m.Sporttype,
				b.TransID,
				ISNULL(b.BetID, 0),
				b.Bettype,
				b.hdp1, 
				b.hdp2,
				modds,
				b.oddstype,
				b.Odds,
				b.stake,
				b.actual_stake, 
				b.betteam,
				b.status,
				b.refno,
				b.Transdate,
				b.winlostdate,
				(b.winlost-actual_stake),
				- (b.winlost-actual_stake),
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
				0,
				0,
				b.currency,
				CASE 
					WHEN sbt.ProductID = 4 THEN ISNULL(m.showtime, '')
					ELSE '' 
				END AS ShowTime,
				'' AS betcheck,
				'' AS transdesc
			FROM
				dbo.bettrans AS b WITH (NOLOCK)
				INNER JOIN dbo.match AS m WITH (NOLOCK) ON b.matchid = m.matchid
				INNER JOIN @SportBettype AS sbt ON b.Bettype = sbt.Bettype
			WHERE
				b.winlostdate BETWEEN @TempFromDate AND @tdate 
				AND b.custid = @custid 
				AND (@currencyID = 0 OR b.currency = @currencyID ) 
				AND sbt.ProductID IN (3, 4)
				AND b.statusID IN (111, 112, 113)
		END

		-- Virtual Sports
		IF @ShowVS = 1
		BEGIN
			INSERT INTO @BetListByDateMem
			SELECT
				m.Sporttype,
				b.TransID,
				ISNULL(b.BetID, 0),
				b.Bettype,
				b.hdp1, 
				b.hdp2,
				modds,
				b.oddstype,
				b.Odds,
				b.stake,
				b.actual_stake, 
				b.betteam,
				b.status,
				b.refno,
				b.Transdate,
				b.winlostdate,
				(b.winlost-actual_stake),
				- (b.winlost-actual_stake),
				b.comm,
				b.playercomm,
				b.Liveindicator,
				b.Livehomescore,
				b.Liveawayscore,
				b.IP,
				m.leagueid,
				m.matchid,
				m.matchcode,
				'' AS Race,
				m.homeid,
				m.awayid,
				m.Betstatus,
				ISNULL(m.isNeutral, CONVERT(BIT,0)) AS IsNeutral,
				0,
				0,
				b.currency,
				CONVERT(NVARCHAR(50), m.kickofftime) AS ShowTime,
				'' AS betcheck,
				'' AS transdesc
			FROM
				dbo.bettrans AS b WITH (NOLOCK)
				INNER JOIN dbo.match AS m WITH (NOLOCK) ON b.matchid = m.matchid
				INNER JOIN @SportBettype AS sbt ON b.Bettype = sbt.Bettype
			WHERE
				b.winlostdate BETWEEN @TempFromDate AND @tdate
				AND b.custid = @custid
				AND (@currencyID = 0 OR b.currency = @currencyID )
				AND sbt.ProductID = 5
				AND sbt.EventType = 1
				AND b.statusID IN (111, 112, 113)

			UNION ALL

			SELECT 
				r.sporttype,
				b.transid,
				ISNULL(b.BetID, 0),
				b.Bettype,
				b.hdp1,
				b.hdp2,
				modds,
				b.oddstype,
				b.Odds,
				b.stake,
				b.actual_stake,
				b.betteam,
				b.status,
				b.refno,
				b.Transdate,
				b.winlostdate,
				(b.winlost-actual_stake),
				- (b.winlost-actual_stake),
				b.comm,
				b.playercomm,
				b.Liveindicator,
				b.Livehomescore,
				b.Liveawayscore,
				b.IP,
				r.LeagueID,
				o.EventID MatchID,
				CONVERT(VARCHAR(50),o.RacerNum) MatchCode,
				b.oddsid AS Race,
				o.RacerID HomeID,
				0 AS AwayID,
				r.Betstatus,
				ISNULL(0, CONVERT(BIT,0)) AS IsNeutral,
				0,
				0,
				b.currency,
				CONVERT(VARCHAR(20),r.EventTime) AS showtime,
				'' AS betcheck,
				'' AS transdesc
			FROM dbo.bettrans AS b WITH (NOLOCK)
				INNER JOIN VSOutright AS o WITH (NOLOCK) ON b.oddsid = o.Orid
				INNER JOIN VSRaceInfo AS r WITH (NOLOCK) ON r.EventID = o.EventID
				INNER JOIN @SportBettype AS sbt ON b.Bettype = sbt.Bettype
			WHERE
				b.winlostdate BETWEEN @TempFromDate AND @tdate
				AND b.custid = @custid 
				AND (@currencyID = 0 OR b.currency = @currencyID)
				AND sbt.ProductID = 5 
				AND sbt.EventType = 3 
				AND b.statusID IN (111, 112, 113)
		END

		-- RNG Casino, Microgaming Live Casino
		IF @ShowCS = 1 OR @ShowMGCLC = 1
		BEGIN
			INSERT INTO @BetListByDateMem
			SELECT
				CASE
					WHEN sbt.ProductID = 6 THEN 251
					WHEN sbt.ProductID = 13 THEN 203
				END AS Sporttype,
				b.transid,
				ISNULL(b.BetID, 0),
				b.Bettype,
				b.hdp1, 
				b.hdp2,
				b.modds,
				ISNULL(b.oddstype, 0),
				b.Odds,
				b.stake,
				b.actual_stake, 
				ISNULL(b.betteam,0),
				b.status,
				b.refno,
				b.transdate,
				b.winlostdate,
				(b.winlost - actual_stake),
				- (b.winlost - actual_stake),
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
				0,
				0,
				b.currency,
				'' AS showtime,
				CASE
					WHEN sbt.ProductID = 13 THEN b.betcheck
					ELSE ''
				END AS betcheck,
				'' AS transdesc
			FROM
				dbo.bettrans AS b WITH (NOLOCK)
				INNER JOIN @SportBettype sbt ON b.Bettype = sbt.Bettype
			WHERE
				b.winlostdate BETWEEN @TempFromDate AND @tdate 
				AND b.custid = @custid 
				AND (@currencyID = 0 OR b.currency = @currencyID )
				AND (sbt.ProductID = 13
					OR (sbt.ProductID = 6 AND sbt.SubProduct = ''))
				AND b.statusID IN (111, 112, 113)
		END

		-- Horse Racing
		IF @ShowRB = 1
		BEGIN
			INSERT INTO @BetListByDateMem
			SELECT
				l.sporttype,
				b.TransID,
				ISNULL(b.BetID, 0),
				b.Bettype,
				b.hdp1,
				b.hdp2,
				modds,
				0 AS OddsType,
				b.Odds,
				b.stake,
				b.actual_stake,
				'' AS Betteam,
				b.Status,
				b.refno,
				b.Transdate,
				b.winlostdate,
				(b.winlost-actual_stake),
				awinlost,
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
				b.virtualrate,
				ISNUMERIC(m.programID),
				b.currency,
				'' AS ShowTime,
				'' AS betcheck,
				'' AS transdesc
			FROM
				dbo.bettrans AS b WITH (NOLOCK)
				INNER JOIN dbo.Outright AS m WITH (NOLOCK) ON b.matchid = m.orid
				INNER JOIN dbo.League AS l WITH (NOLOCK) ON m.leagueID = l.leagueID
				INNER JOIN @SportBettype AS sbt ON b.Bettype = sbt.Bettype
			WHERE
				b.winlostdate BETWEEN @TempFromDate AND @tdate 
				AND b.custid = @custid 
				AND (@currencyID = 0 OR b.currency = @currencyID ) 
				AND sbt.ProductID = 2 
				AND b.statusID IN (111, 112, 113)
		END

		-- Keno
		IF @ShowKN = 1
		BEGIN
			INSERT INTO @BetListByDateMem
			SELECT
				202 AS Sporttype,
				b.transid,
				ISNULL(b.BetID, 0),
				b.Bettype,
				b.hdp1, 
				b.hdp2,
				b.modds,
				b.oddstype,
				b.Odds,
				b.stake,
				b.actual_stake, 
				ChoiceId AS betteam,
				b.status,
				b.refno,
				b.transdate,
				b.winlostdate,
				(b.winlost-actual_stake),
				- (b.winlost-actual_stake),
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
				CONVERT(BIT, 0) AS IsNeutral,
				0,
				0,
				b.currency,
				'' AS showtime,
				'' AS betcheck,
				'' AS transdesc
			FROM
				dbo.bettrans AS b WITH (NOLOCK)
				CROSS APPLY dbo.f_ParseTransDesc(b.transdesc, b.bettype)
				INNER JOIN @SportBettype AS sbt ON b.Bettype = sbt.Bettype
			WHERE
				b.winlostdate BETWEEN @TempFromDate AND @tdate 
				AND b.custid = @custid 
				AND (@currencyID = 0 OR b.currency = @currencyID ) 
				AND sbt.ProductID = 8 
				AND b.statusID IN (111, 112, 113)
		END

		-- Microgaming RNG Casino, RNG Casino Single Wallet, Voidbridge, Fishing World
		IF @ShowCS = 1 OR @ShowMGCRNG = 1 OR @ShowVB = 1 OR @ShowFW = 1
		BEGIN
			-- Up to yesterday settled ticket
			INSERT INTO @BetListByDateMem
			SELECT
				CASE
					WHEN sbt.ProductID = 6 THEN b.matchid
					WHEN sbt.ProductID = 17 THEN 205
					WHEN sbt.ProductID = 22 THEN 212
					WHEN sbt.ProductID = 24 THEN 219
				END AS Sporttype,
				b.transid,
				ISNULL(b.BetID, 0),
				b.Bettype,
				0 AS hdp1,
				0 AS hdp2,
				0 AS modds,
				0 AS oddstype,
				0 AS Odds,
				b.stake,
				b.actual_stake,
				'' AS betteam,
				b.status,
				b.refno,
				b.transdate,
				b.winlostdate,
				(b.winlost - b.actual_stake) AS Winlost,
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
				0,
				0,
				b.currency,
				'' AS showtime,
				'' AS betcheck,
				CASE
					WHEN sbt.ProductID IN (6, 22, 24) THEN b.transdesc
					ELSE ''
				END AS transdesc
			FROM
				dbo.bettrans AS b WITH (NOLOCK)
				INNER JOIN @SportBettype AS sbt ON b.Bettype = sbt.Bettype
			WHERE
				b.winlostdate BETWEEN @TempFromDate AND @tdate
				AND b.winlostdate < DATEADD(DAY, DATEDIFF(DAY, 1, GETDATE()), 0)	-- not yesterday and today
				AND b.custid = @custid
				AND (@currencyID = 0 OR b.currency = @currencyID) 
				AND (sbt.ProductID IN (17, 22, 24)
					OR (sbt.ProductID = 6 AND sbt.SubProduct <> ''))
				AND b.statusID IN (111, 112, 113)

			IF @tdate >= DATEADD(DAY, DATEDIFF(DAY, 1, GETDATE()), 0)				-- yesterday
				AND @TempFromDate <= DATEADD(DAY, DATEDIFF(DAY, 0, GETDATE()), 0)	-- today
			BEGIN
				-- Today settled ticket
				INSERT INTO @BetListByDateMem
				SELECT
					CASE
						WHEN sbt.ProductID = 6 THEN b.matchid
						WHEN sbt.ProductID = 17 THEN 205
						WHEN sbt.ProductID = 22 THEN 212
						WHEN sbt.ProductID = 24 THEN 219
					END AS Sporttype,
					b.transid,
					ISNULL(b.BetID, 0),
					b.Bettype,
					0 AS hdp1,
					0 AS hdp2,
					0 AS modds,
					0 AS oddstype,
					0 AS Odds,
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
					SUM(- (brng.winlost - brng.actual_stake)) AS LicenseeWL,
					SUM(brng.comm) AS comm,
					SUM(brng.playercomm) AS playercomm,
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
					0,
					0,
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
				WHERE b.winlostdate BETWEEN @TempFromDate AND @tdate
					AND b.winlostdate BETWEEN DATEADD(DAY, DATEDIFF(DAY, 1, GETDATE()), 0) 
						AND DATEADD(DAY, DATEDIFF(DAY, 0, GETDATE()), 0)		-- yesterday and today
					AND b.custid = @custid 
					AND (@currencyID = 0 OR b.currency = @currencyID) 
					AND (sbt.ProductID IN (17, 22, 24)
						OR (sbt.ProductID = 6 AND sbt.SubProduct <> ''))
					AND brng.statusID <> 0
				GROUP BY
					b.transid,
					ISNULL(b.BetID, 0),
					b.Bettype,
					b.refno,
					b.transdate,
					b.winlostdate,
					b.IP,
					b.currency,
					b.matchid,
					b.transdesc,
					sbt.ProductID
			END
		END

		-- AG Casino, AllBet
		IF @ShowAGC = 1 OR @ShowAB = 1
		BEGIN
			-- AG Casino, AllBet (up to yesterday settled ticket)
			INSERT INTO @BetListByDateMem
			SELECT
				CASE
					WHEN sbt.ProductID = 11 THEN 250
					WHEN sbt.ProductID = 21 THEN 211
				END AS Sporttype,
				b.transid,
				ISNULL(b.BetID, 0),
				b.Bettype,
				0 AS hdp1,
				0 AS hdp2,
				0 AS modds,
				0 AS oddstype,
				0 AS Odds,
				b.stake,
				b.actual_stake,
				'' AS betteam,
				b.status,
				b.refno,
				b.transdate,
				b.winlostdate,
				(b.winlost - b.actual_stake) AS Winlost,
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
				0,
				0,
				b.currency,
				'' AS showtime,
				'' AS betcheck,
				'' AS transdesc
			FROM
				dbo.bettrans AS b WITH (NOLOCK)
				INNER JOIN @SportBettype AS sbt ON b.Bettype = sbt.Bettype
			WHERE
				b.winlostdate BETWEEN @TempFromDate AND @tdate 
				AND b.winlostdate < DATEADD(DAY, DATEDIFF(DAY, 1, GETDATE()), 0)	-- not yesterday and today
				AND b.custid = @custid 
				AND (@currencyID = 0 OR b.currency = @currencyID) 
				AND sbt.ProductID IN (11, 21)
				AND b.statusID IN (111, 112, 113)

			IF @tdate >= DATEADD(DAY, DATEDIFF(DAY, 1, GETDATE()), 0)				-- yesterday
				AND @TempFromDate <= DATEADD(DAY, DATEDIFF(DAY, 0, GETDATE()), 0)	-- today
			BEGIN
				-- Today settled ticket
				INSERT INTO @BetListByDateMem
				SELECT
					CASE
						WHEN sbt.ProductID = 11 THEN 250
						WHEN sbt.ProductID = 21 THEN 211
					END AS Sporttype,
					b.transid,
					ISNULL(b.BetID, 0),
					b.Bettype,
					0 AS hdp1,
					0 AS hdp2,
					0 AS modds,
					0 AS oddstype,
					0 AS Odds,
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
					SUM(- (blc.winlost - blc.actual_stake)) AS LicenseeWL,
					SUM(blc.comm) AS comm,
					SUM(blc.playercomm) AS playercomm,
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
					0,
					0,
					b.currency,
					'' AS showtime,
					'' AS betcheck,
					'' AS transdesc
				FROM
					dbo.bettransLC AS blc WITH (NOLOCK)
					INNER JOIN dbo.bettrans AS b WITH (NOLOCK) ON blc.RefNo = b.transid
					INNER JOIN @SportBettype AS sbt ON b.Bettype = sbt.Bettype
				WHERE b.winlostdate BETWEEN @TempFromDate AND @tdate
					AND b.winlostdate BETWEEN DATEADD(DAY, DATEDIFF(DAY, 1, GETDATE()), 0) 
						AND DATEADD(DAY, DATEDIFF(DAY, 0, GETDATE()), 0)		-- yesterday and today
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

		-- Colossus Bets
		IF @ShowCB = 1
		BEGIN
			INSERT INTO @BetListByDateMem
			SELECT
				204 AS SportType,
				b.transid,
				ISNULL(b.betid, 0),
				b.bettype,
				0 AS Hdp1,
				0 AS Hdp2,
				0 AS MOdds,
				0 AS OddsType,
				0 AS Odds,
				b.stake,
				b.actual_stake,
				'' AS BetTeam,
				b.status,
				b.refno,
				b.transdate,
				b.winlostdate,
				(b.winlost - actual_stake) AS WinLost,
				0 AS LicenseeWL,
				b.comm,
				b.playercomm,
				0 AS LiveIndicator,
				0 AS LiveHomeScore,
				0 AS LiveAwayScore,
				b.ip,
				0 AS LeagueId,
				0 AS MatchId,
				'' AS MatchCode,
				'' AS Race,
				0 AS HomeId,
				0 AS AwayId,
				0 AS Betstatus,
				CONVERT(BIT, 0) AS IsNeutral,
				0 AS VirtualRate,
				0 AS IsShowOTExRate,
				b.currency,
				'' AS ShowTime,
				ISNULL(bm.betcheck, '') AS BetCheck,
				'' AS transdesc
			FROM
				dbo.bettrans AS b WITH (NOLOCK)
				INNER JOIN @SportBettype sbt ON b.bettype = sbt.Bettype
				LEFT JOIN dbo.bettransm AS bm WITH (NOLOCK) ON b.refno = bm.refno AND bm.bettype = 18001
			WHERE
				b.winlostdate BETWEEN @TempFromDate AND @tdate 
				AND b.custid = @custid 
				AND (@currencyID = 0 OR b.currency = @currencyID )
				AND b.statusID IN (111, 112, 113)
				AND sbt.ProductID = 15
		END
	END

	IF @fdate <= @MoveBetsDay AND @tdate >= @BalanceUpDay
	BEGIN
		IF @tdate >= @MoveBetsDay
			SET @TempToDate = @MoveBetsDay
		ELSE
			SET @TempToDate = @tdate
	
		IF @BalanceUpDay < @fdate 
			SELECT @BalanceUpDay = @fdate

		-- BA Tickets
		DELETE FROM @TempBetList
		
		INSERT INTO @TempBetList
		SELECT
			b.TransID,
			ISNULL(b.BetID, 0),
			b.Bettype,
			b.hdp1,
			b.hdp2,
			b.modds,
			b.OddsType,
			b.Odds,
			b.stake,
			b.actual_stake,
			b.betteam,
			b.status,
			b.refno,
			b.Transdate,
			b.winlostdate,
			(b.winlost-actual_stake),
			0,
			b.comm,
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
			dbo.bettrans14 AS b WITH (NOLOCK)
			INNER JOIN DBLIC.bodb_Licensee.dbo.LicenseeBATransaction AS BA WITH (NOLOCK) ON b.transid = BA.transid
		WHERE
			b.winlostdate BETWEEN @BalanceUpDay AND @TempToDate AND
			b.custid = @custid AND (@currencyID = 0 OR b.currency = @currencyID ) AND
			b.statusID IN (111, 112, 113) AND
			b.bettype NOT IN (901, 902, 903)

		IF @ShowBA = 1
		BEGIN
			-- Sportsbook
			INSERT INTO @BetListByDateMem
			SELECT
				m.Sporttype,
				b.TransID,
				b.BetID,
				b.Bettype,
				b.hdp1,
				b.hdp2,
				b.modds,
				b.oddstype,
				b.odds,
				b.stake,
				b.actual_stake,
				b.betteam,
				b.status,
				b.refno,
				b.Transdate,
				b.winlostdate,
				b.Winlost,
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
				0,
				0,
				b.currency,
				'' AS ShowTime,
				b.betcheck,
				b.transdesc
			FROM
				@TempBetList AS b
				INNER JOIN dbo.match14 AS m WITH (NOLOCK) ON b.matchid = m.matchid
				INNER JOIN @SportBettype AS sbt ON b.Bettype = sbt.Bettype
			WHERE sbt.ProductID = 1 AND sbt.EventType = 1

			-- Outright
			INSERT INTO @BetListByDateMem
			SELECT
				l.sporttype,
				b.TransID,
				b.BetID,
				b.Bettype,
				0 AS hdp1,
				0 AS hdp2,
				b.modds,
				0 AS OddsType,
				b.Odds,
				b.stake,
				b.actual_stake,
				'' AS Betteam,
				b.Status,
				b.refno,
				b.Transdate,
				b.winlostdate,
				b.Winlost,
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
				0,
				0,
				b.currency,
				'' AS ShowTime,
				'' AS betcheck,
				'' AS transdesc
			FROM
				@TempBetList AS b
				INNER JOIN dbo.Outright14 AS m WITH (NOLOCK) ON b.matchid = m.orid
				INNER JOIN dbo.League AS l WITH (NOLOCK) ON m.leagueID = l.leagueID
				INNER JOIN @SportBettype AS sbt ON b.Bettype = sbt.Bettype
			WHERE sbt.ProductID = 1 AND sbt.EventType = 2

			-- Mix Parlay + System Parlay
			INSERT INTO @BetListByDateMem
			SELECT
				0, --Sporttype
				CASE
					WHEN b.bettype <> 29 THEN b.transid
					ELSE CASE WHEN ISNULL(b.BetID,0) = 0 THEN b.transid ELSE betid END
				END AS transid,
				b.BetID,
				b.bettype,
				b.hdp1, 
				b.hdp2, 
				modds,
				0 AS OddsType, 
				b.Odds, 
				b.stake,
				b.actual_stake,  
				b.betteam,
				b.Status,
				b.refno,
				b.Transdate,
				b.winlostdate,
				b.Winlost,
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
				0,
				0,
				b.currency,
				'' AS ShowTime,
				ISNULL(b.betcheck, '') AS BetCheck,
				'' AS transdesc
			FROM
				@TempBetList AS b
				INNER JOIN @SportBettype AS sbt ON b.Bettype = sbt.Bettype
			WHERE
				b.matchid IN (9, 29)
				AND sbt.ProductID = 1
				AND sbt.EventType = 0
		END

		-- Sportsbook
		IF @ShowSB = 1
		BEGIN
			INSERT INTO @BetListByDateMem
			SELECT
				m.Sporttype,
				b.TransID,
				ISNULL(b.BetID, 0),
				b.Bettype,
				b.hdp1, 
				b.hdp2, 
				modds,
				b.Oddstype,
				b.Odds,
				b.stake,
				b.actual_stake,
				b.betteam,
				b.status,
				b.refno,
				b.Transdate,
				b.winlostdate,
				(b.winlost-actual_stake),
				- (b.winlost-actual_stake),
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
				0,
				0,
				b.currency,
				'' AS ShowTime,
				b.betcheck,
				ISNULL(b.transdesc, '') AS transdesc
			FROM
				dbo.bettrans14 AS b WITH (NOLOCK)
				INNER JOIN dbo.match14 AS m WITH (NOLOCK) ON b.matchid = m.matchid
				INNER JOIN @SportBettype AS sbt ON b.Bettype = sbt.Bettype
			WHERE
				b.winlostdate BETWEEN @BalanceUpDay AND @TempToDate 
				AND b.custid = @custid 
				AND (@currencyID = 0 OR b.currency = @currencyID) 
				AND b.bettype NOT IN (901, 902, 903)
				AND sbt.ProductID = 1
				AND sbt.EventType = 1
				AND b.matchid > 0 
				AND b.statusID IN (111, 112, 113)
				AND b.transid NOT IN (SELECT Transid FROM @TempBetList) --exclude BA tickets

			-- Mix Parlay + System Parlay
			INSERT INTO @BetListByDateMem
			SELECT
				0, --Sporttype
				CASE
					WHEN b.bettype <> 29 THEN b.transid
					ELSE CASE WHEN ISNULL(b.BetID,0)=0 THEN b.transid ELSE betid END
				END AS transid,
				ISNULL(b.BetID, 0),
				b.bettype,
				b.hdp1, 
				b.hdp2, 
				modds,
				0 AS OddsType, 
				b.Odds, 
				b.stake,
				b.actual_stake,
				b.betteam,
				b.Status,
				b.refno,
				b.Transdate,
				b.winlostdate,
				(b.winlost-actual_stake),
				- (b.winlost-actual_stake),
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
				CONVERT(BIT,0) AS isNeutral,
				0,
				0,
				b.currency,
				'' AS ShowTime,
				ISNULL(b.betcheck, '') AS BetCheck,
				'' AS transdesc
			FROM
				dbo.bettrans14 AS b WITH (NOLOCK)
				INNER JOIN @SportBettype AS sbt ON b.Bettype = sbt.Bettype
			WHERE
				b.winlostdate BETWEEN @BalanceUpDay AND @TempToDate 
				AND b.custid = @custid
				AND (@currencyID = 0 OR b.currency = @currencyID) 
				AND sbt.ProductID = 1
				AND sbt.EventType = 0
				AND b.matchid IN (9, 29)
				AND b.statusID IN (111, 112, 113) 
				AND b.transid NOT IN (SELECT Transid FROM @TempBetList) --exclude BA tickets

			-- Outright
			INSERT INTO @BetListByDateMem
			SELECT
				l.sporttype,
				b.TransID,
				ISNULL(b.BetID, 0),
				b.Bettype,
				0 AS hdp1,
				0 AS hdp2,
				modds,
				0 AS OddsType,
				b.Odds,
				b.stake,
				b.actual_stake,
				'' AS Betteam,
				b.Status,
				b.refno,
				b.Transdate,
				b.winlostdate,
				(b.winlost-actual_stake),
				- (b.winlost-actual_stake),
				b.comm,
				b.playercomm,
				0 AS LiveIndicator,
				b.LiveHomescore,
				b.LiveAwayscore,
				b.IP,
				m.LeagueID,
				m.OrId, --MatchID
				m.MatchCode,
				m.GroupMatch AS Race,
				m.TeamID, --HomeID
				0, --AwayID
				0, --Betstatus
				CONVERT(BIT,0) AS isNeutral,
				0,
				0,
				b.currency,
				'' AS ShowTime,
				'' AS betcheck,
				'' AS transdesc
			FROM
				dbo.bettrans14 AS b WITH (NOLOCK)
				INNER JOIN dbo.Outright14 AS m WITH (NOLOCK) ON b.matchid = m.orid
				INNER JOIN dbo.League AS l WITH (NOLOCK) ON m.leagueID = l.leagueID
				INNER JOIN @SportBettype AS sbt ON b.Bettype = sbt.Bettype
			WHERE
				b.winlostdate BETWEEN @BalanceUpDay AND @TempToDate 
				AND b.custid = @custid 
				AND (@currencyID = 0 OR b.currency = @currencyID ) 
				AND sbt.ProductID = 1 
				AND sbt.EventType = 2 
				AND b.statusID IN (111, 112, 113) 
				AND b.transid NOT IN (SELECT Transid FROM @TempBetList) --exclude BA tickets
		END
	
		-- Bet trade
		IF @ShowBT = 1
		BEGIN
			INSERT INTO @BetListByDateMem
			SELECT
				m.Sporttype,
				b.TransID,
				ISNULL(ob.bettype,0),
				b.Bettype,
				b.hdp1,
				b.hdp2,
				b.modds,
				b.Oddstype,
				ob.Odds,
				ob.stake,
				b.actual_stake,
				b.betteam,
				b.status,
				b.refno,
				b.Transdate,
				b.winlostdate,
				(b.winlost-b.actual_stake),
				- (b.winlost-b.actual_stake),
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
				0,
				0,
				b.currency,
				'' AS ShowTime,
				b.betcheck,
				'' AS transdesc
			FROM
				dbo.bettrans14 AS b WITH (NOLOCK)
				INNER JOIN dbo.bettrans14 AS ob WITH(NOLOCK) ON b.refno = ob.transid
				INNER JOIN dbo.match14 AS m WITH (NOLOCK) ON b.matchid = m.matchid
				INNER JOIN @SportBettype AS sbt ON b.Bettype = sbt.Bettype
			WHERE
				b.winlostdate BETWEEN @BalanceUpDay AND @TempToDate 
				AND b.custid = @custid 
				AND (@currencyID = 0 OR b.currency = @currencyID) 
				AND b.bettype IN (901, 902, 903) 
				AND sbt.ProductID = 1
				AND sbt.EventType = 1
				AND b.matchid > 0 
				AND b.statusID IN (111, 112, 113)
		END

		-- Number Game, Live Casino
		IF @ShowNG = 1 OR @ShowLC = 1
		BEGIN
			INSERT INTO @BetListByDateMem
			SELECT
				m.Sporttype,
				b.TransID,
				ISNULL(b.BetID, 0),
				b.Bettype,
				b.hdp1,
				b.hdp2,
				modds,
				b.Oddstype,
				b.Odds,
				b.stake,
				b.actual_stake,
				b.betteam,
				b.status,
				b.refno,
				b.Transdate,
				b.winlostdate,
				(b.winlost-actual_stake),
				- (b.winlost-actual_stake),
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
				0,
				0,
				b.currency,
				CASE 
					WHEN sbt.ProductID = 4 THEN ISNULL(m.showtime, '')
					ELSE '' 
				END AS ShowTime,
				'' AS betcheck,
				'' AS transdesc
			FROM
				dbo.bettrans14 AS b WITH (NOLOCK)
				INNER JOIN dbo.match14 AS m WITH (NOLOCK) ON b.matchid = m.matchid
				INNER JOIN @SportBettype AS sbt ON b.Bettype = sbt.Bettype
			WHERE
				b.winlostdate BETWEEN @BalanceUpDay AND @tdate 
				AND b.custid = @custid
				AND (@currencyID = 0 OR b.currency = @currencyID)
				AND sbt.ProductID IN (3, 4)
				AND b.statusID IN (111, 112, 113)
		END

		-- Virtual Sports
		IF @ShowVS = 1
		BEGIN
			INSERT INTO @BetListByDateMem
			SELECT
				m.Sporttype, 
				b.TransID,
				ISNULL(b.BetID, 0),
				b.Bettype,
				b.hdp1, 
				b.hdp2,
				modds,
				b.Oddstype,
				b.Odds,
				b.stake,
				b.actual_stake,
				b.betteam,
				b.status,
				b.refno,
				b.Transdate,
				b.winlostdate,
				(b.winlost-actual_stake),
				- (b.winlost-actual_stake),
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
				0,
				0,
				b.currency,
				CONVERT(NVARCHAR(50), m.kickofftime) AS ShowTime,
				'' AS betcheck,
				'' AS transdesc
			FROM
				dbo.bettrans14 AS b WITH (NOLOCK)
				INNER JOIN dbo.match14 AS m WITH (NOLOCK) ON b.matchid = m.matchid
				INNER JOIN @SportBettype AS sbt ON b.Bettype = sbt.Bettype
			WHERE
				b.winlostdate BETWEEN @BalanceUpDay AND @tdate 
				AND b.custid = @custid 
				AND (@currencyID = 0 OR b.currency = @currencyID ) 
				AND sbt.ProductID = 5 
				AND sbt.EventType = 1 
				AND b.statusID IN (111, 112, 113)

			UNION ALL

			SELECT 
				r.sporttype,
				b.transid,
				ISNULL(b.BetID, 0),
				b.Bettype,
				b.hdp1, 
				b.hdp2,
				modds,
				b.oddstype,
				b.Odds,
				b.stake,
				b.actual_stake, 
				b.betteam,
				b.status,
				b.refno,
				b.Transdate,
				b.winlostdate,
				(b.winlost-actual_stake),
				- (b.winlost-actual_stake),
				b.comm,
				b.playercomm,
				b.Liveindicator,
				b.Livehomescore,
				b.Liveawayscore,
				b.IP,
				r.LeagueID,
				o.EventID MatchID,
				CONVERT(VARCHAR(50),o.RacerNum) MatchCode,
				b.oddsid AS Race,
				o.RacerID HomeID,
				0 AS AwayID,
				r.Betstatus,
				ISNULL(0, CONVERT(BIT,0)) AS IsNeutral,
				0,
				0,
				b.currency,
				CONVERT(VARCHAR(20), r.EventTime) AS showtime,
				'' AS betcheck,
				'' AS transdesc
			FROM dbo.bettrans14 AS b WITH (NOLOCK)
				INNER JOIN VSOutright14 AS o WITH (NOLOCK) ON b.oddsid = o.Orid
				INNER JOIN VSRaceInfo AS r WITH (NOLOCK) ON r.EventID = o.EventID
				INNER JOIN @SportBettype AS sbt ON b.Bettype = sbt.Bettype
			WHERE
				b.winlostdate BETWEEN @BalanceUpDay AND @tdate 
				AND b.custid = @custid 
				AND (@currencyID = 0 OR b.currency = @currencyID ) 
				AND sbt.ProductID = 5 
				AND sbt.EventType = 3 
				AND b.statusID IN (111, 112, 113)
		END

		-- RNG Casino, Microgaming Live Casino, Microgaming RNG Casino, AG Casino, AllBet, Voidbridge, Fishing World
		IF @ShowCS = 1 OR @ShowMGCLC = 1 OR @ShowMGCRNG = 1 OR @ShowAGC = 1 OR @ShowAB = 1 OR @ShowVB = 1 OR @ShowFW = 1
		BEGIN
			INSERT INTO @BetListByDateMem
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
				b.transid,
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
					WHEN sbt.ProductID = 6 AND sbt.SubProduct = '' THEN b.modds
					ELSE 0
				END AS modds,
				CASE
					WHEN sbt.ProductID = 6 AND sbt.SubProduct = '' THEN b.oddstype
					ELSE 0
				END AS Oddstype,
				CASE
					WHEN sbt.ProductID = 6 AND sbt.SubProduct = '' THEN b.Odds
					ELSE 0
				END AS Odds,
				b.stake,
				b.actual_stake,
				CASE
					WHEN sbt.ProductID = 6 AND sbt.SubProduct = '' THEN ISNULL(b.betteam, '')
					ELSE ''
				END AS Betteam,
				b.status,
				b.refno,
				b.Transdate,
				b.winlostdate,
				(b.winlost - actual_stake),
				- (b.winlost - actual_stake),
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
				0,
				0,
				b.currency,
				'' AS showtime,
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
				dbo.bettrans14 AS b WITH (NOLOCK)
				INNER JOIN @SportBettype AS sbt ON b.Bettype = sbt.Bettype
			WHERE
				b.winlostdate BETWEEN @BalanceUpDay AND @tdate 
				AND b.custid = @custid 
				AND (@currencyID = 0 OR b.currency = @currencyID)
				AND sbt.ProductID IN (6, 11, 13, 17, 21, 22, 24)
				AND b.statusID IN (111, 112, 113)
		END

		-- Horse Racing
		IF @ShowRB = 1
		BEGIN
			INSERT INTO @BetListByDateMem
			SELECT
				l.sporttype,
				b.TransID,
				ISNULL(b.BetID, 0),
				b.Bettype,
				b.hdp1,
				b.hdp2,
				modds,
				0 AS OddsType,
				b.Odds,
				b.stake,
				b.actual_stake,
				'' AS Betteam,
				b.Status,
				b.refno,
				b.Transdate,
				b.winlostdate,
				(b.winlost-actual_stake),
				awinlost,
				b.comm,
				b.playercomm,
				0 AS LiveIndicator,
				b.LiveHomescore,
				b.LiveAwayscore,
				b.IP,
				m.LeagueID,
				m.OrId, --MatchID
				m.MatchCode,
				m.GroupMatch AS Race,
				m.TeamID, --HomeID
				0, --AwayID
				0, --Betstatus
				CONVERT(BIT,0) AS isNeutral,
				b.virtualrate,
				ISNUMERIC(m.programID),
				b.currency,
				'' AS ShowTime,
				'' AS betcheck,
				'' AS transdesc
			FROM
				dbo.bettrans14 AS b WITH (NOLOCK)
				INNER JOIN dbo.Outright14 AS m WITH (NOLOCK) ON b.matchid = m.orid
				INNER JOIN dbo.League AS l WITH (NOLOCK) ON m.leagueID = l.leagueID
				INNER JOIN @SportBettype AS sbt ON b.Bettype = sbt.Bettype
			WHERE
				b.winlostdate BETWEEN @BalanceUpDay AND @TempToDate 
				AND b.custid = @custid 
				AND (@currencyID = 0 OR b.currency = @currencyID) 
				AND sbt.ProductID = 2 
				AND b.statusID IN (111, 112, 113)
		END

		-- Keno
		IF @ShowKN = 1
		BEGIN
			INSERT INTO @BetListByDateMem
			SELECT
				202 AS Sporttype,
				b.transid,
				ISNULL(b.BetID, 0),
				b.Bettype,
				0 AS hdp1, 
				0 AS hdp2,
				b.modds,
				b.Oddstype,
				b.Odds,
				b.stake,
				b.actual_stake,
				ChoiceID AS betteam,
				b.status,
				b.refno,
				b.Transdate,
				b.winlostdate,
				(b.winlost - actual_stake),
				- (b.winlost - actual_stake),
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
				0,
				0,
				b.currency,
				'' AS showtime,
				'' AS betcheck,
				'' AS transdesc
			FROM
				dbo.bettrans14 AS b WITH (NOLOCK)
				CROSS APPLY dbo.f_ParseTransDesc(b.transdesc, b.bettype)
				INNER JOIN @SportBettype AS sbt ON b.Bettype = sbt.Bettype
			WHERE
				b.winlostdate BETWEEN @BalanceUpDay AND @tdate 
				AND b.custid = @custid 
				AND (@currencyID = 0 OR b.currency = @currencyID ) 
				AND sbt.ProductID = 8 
				AND b.statusID IN (111, 112, 113)
		END

		-- Colossus Bets
		IF @ShowCB = 1
		BEGIN
			INSERT INTO @BetListByDateMem
			SELECT
				204 AS SportType,
				b.transid,
				ISNULL(b.betid, 0),
				b.bettype,
				0 AS Hdp1,
				0 AS Hdp2,
				0 AS MOdds,
				0 AS OddsType,
				0 AS Odds,
				b.stake,
				b.actual_stake,
				'' AS BetTeam,
				b.status,
				b.refno,
				b.transdate,
				b.winlostdate,
				(b.winlost - actual_stake) AS WinLost,
				0 AS LicenseeWL,
				b.comm,
				b.playercomm,
				0 AS LiveIndicator,
				0 AS LiveHomeScore,
				0 AS LiveAwayScore,
				b.ip,
				0 AS LeagueId,
				0 AS MatchId,
				'' AS MatchCode,
				'' AS Race,
				0 AS HomeId,
				0 AS AwayId,
				0 AS Betstatus,
				CONVERT(BIT, 0) AS IsNeutral,
				0 AS VirtualRate,
				0 AS IsShowOTExRate,
				b.currency,
				'' AS ShowTime,
				ISNULL(bm.betcheck, '') AS BetCheck,
				'' AS transdesc
			FROM
				dbo.bettrans14 AS b WITH (NOLOCK)
				INNER JOIN @SportBettype sbt ON b.bettype = sbt.Bettype
				LEFT JOIN dbo.bettransm14 AS bm WITH (NOLOCK) ON b.refno = bm.refno AND bm.bettype = 18001
			WHERE
				b.winlostdate BETWEEN @BalanceUpDay AND @tdate
				AND b.custid = @custid 
				AND (@currencyID = 0 OR b.currency = @currencyID )
				AND b.statusID IN (111, 112, 113)
				AND sbt.ProductID = 15
		END
	END

	IF @fdate < @BalanceUpDay
	BEGIN
		IF @tdate >= DATEADD(dd, -1, @BalanceUpDay)
			SET @TempToDate = DATEADD(dd, -1, @BalanceUpDay)
		ELSE
			SET @TempToDate = @tdate

		DELETE FROM @TempBetList

		-- BA Tickets
		INSERT INTO @TempBetList
		SELECT
			b.TransID,
			ISNULL(b.BetID, 0),
			b.Bettype,
			b.hdp1,
			b.hdp2,
			b.modds,
			b.OddsType,
			b.Odds,
			b.stake,
			b.actual_stake,
			b.betteam,
			b.status,
			b.refno,
			b.Transdate,
			b.winlostdate,
			(b.winlost-actual_stake),
			0,
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
			bodb_archive.dbo.bettrans_bk AS b WITH (NOLOCK)
			INNER JOIN DBLIC.bodb_Licensee.dbo.LicenseeBATransaction AS BA WITH (NOLOCK) ON b.transid = BA.transid
		WHERE
			b.winlostdate BETWEEN @fdate AND @TempToDate 
			AND b.custid = @custid 
			AND (@currencyID = 0 OR b.currency = @currencyID) 
			AND b.ruben = 1 
			AND b.status NOT IN ('VOID','REJECT','REFUND') 
			AND b.bettype NOT IN (901, 902, 903)
	
		IF @ShowBA = 1
		BEGIN
			-- Sportsbook
			INSERT INTO @BetListByDateMem
			SELECT
				m.Sporttype,
				b.TransID,
				b.BetID,
				b.Bettype,
				b.hdp1,
				b.hdp2,
				b.modds,
				b.oddstype,
				b.odds,
				b.stake,
				b.actual_stake,
				b.betteam,
				b.status,
				b.refno,
				b.Transdate,
				b.winlostdate,
				b.Winlost,
				b.LicenseeWL,
				b.comm,
				b.playercomm,
				b.Liveindicator,
				b.Livehomescore,
				b.Liveawayscore,
				b.IP,
				m.leagueid,
				m.matchid,
				m.matchcode,
				'' AS Race,
				m.HomeID,
				m.AwayID,
				m.Betstatus,
				ISNULL(m.isNeutral, CONVERT(BIT,0)) AS IsNeutral,
				0,
				0,
				b.currency,
				'' AS ShowTime,
				b.betcheck,
				b.transdesc
			FROM
				@TempBetList b
				INNER JOIN bodb_archive.dbo.match_bk AS m WITH (NOLOCK) ON b.matchid = m.matchid
				INNER JOIN @SportBettype sbt ON b.Bettype = sbt.Bettype
			WHERE sbt.ProductID = 1 AND sbt.EventType = 1
			
			-- Outright
			INSERT INTO @BetListByDateMem
			SELECT
				l.sporttype,
				b.TransID,
				b.BetID,
				b.Bettype,
				0 AS hdp1,
				0 AS hdp2,
				b.modds,
				0 AS OddsType,
				b.Odds,
				b.stake,
				b.actual_stake,
				'' AS Betteam,
				b.Status,
				b.refno,
				b.Transdate,
				b.winlostdate,
				b.Winlost,
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
				0,
				0,
				b.currency,
				'' AS ShowTime,
				'' AS betcheck,
				'' AS transdesc
			FROM
				@TempBetList AS b
				INNER JOIN bodb_archive.dbo.Outright_bk AS m WITH (NOLOCK) ON b.matchid = m.orid
				INNER JOIN dbo.League AS l WITH (NOLOCK) ON m.leagueID = l.leagueID
				INNER JOIN @SportBettype AS sbt ON b.Bettype = sbt.Bettype
			WHERE sbt.ProductID = 1 AND sbt.EventType = 2
			
			-- Mix Parlay + System parlay
			INSERT INTO @BetListByDateMem
			SELECT
				0, --Sporttype
				CASE
					WHEN b.bettype <> 29 THEN b.transid
					ELSE CASE WHEN ISNULL(b.BetID,0) = 0 THEN b.transid ELSE betid END
				END AS transid,
				b.BetID,
				b.bettype,
				b.hdp1,
				b.hdp2,
				modds,
				0 AS OddsType,
				b.Odds,
				b.stake,
				b.actual_stake,
				b.betteam,
				b.Status,
				b.refno,
				b.Transdate,
				b.winlostdate,
				b.Winlost,
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
				0,
				0,
				b.currency,
				'' AS ShowTime,
				ISNULL(b.betcheck, '') AS BetCheck,
				'' AS transdesc
			FROM
				@TempBetList AS b
				INNER JOIN @SportBettype AS sbt ON b.Bettype = sbt.Bettype
			WHERE
				sbt.ProductID = 1
				AND sbt.EventType = 0
				AND b.matchid IN (9, 29)
		END

		-- Sportsbook
		IF @ShowSB = 1
		BEGIN
			INSERT INTO @BetListByDateMem
			SELECT
				m.Sporttype,
				b.TransID,
				ISNULL(b.BetID, 0),
				b.Bettype,
				b.hdp1, 
				b.hdp2,
				modds,
				b.Oddstype,
				b.Odds,
				b.stake,
				b.actual_stake,
				b.betteam,
				b.status,
				b.refno,
				b.Transdate,
				b.winlostdate,
				(b.winlost-actual_stake),
				- (b.winlost-actual_stake),
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
				m.HomeID,
				m.AwayID,
				m.Betstatus,
				ISNULL(m.isNeutral, CONVERT(BIT,0)) AS IsNeutral,
				0,
				0,
				b.currency,
				'' AS ShowTime,
				b.betcheck,
				ISNULL(b.transdesc, '') AS transdesc
			FROM
				bodb_archive.dbo.bettrans_bk AS b WITH (NOLOCK)
				INNER JOIN bodb_archive.dbo.match_BK AS m WITH (NOLOCK) ON b.matchid = m.matchid
				INNER JOIN @SportBettype AS sbt ON b.Bettype = sbt.Bettype
			WHERE
				b.winlostdate BETWEEN @fdate AND @TempToDate 
				AND b.custid = @custid 
				AND (@currencyID = 0 OR b.currency = @currencyID)
				AND b.ruben = 1 
				AND b.status NOT IN ('VOID', 'REJECT', 'REFUND')
				AND b.bettype NOT IN (901, 902, 903)
				AND sbt.ProductID = 1 
				AND sbt.EventType = 1 
				AND b.transid NOT IN (SELECT Transid FROM @TempBetList) --exclude BA tickets

			-- Outright
			INSERT INTO @BetListByDateMem
			SELECT
				l.sporttype,
				b.transid,
				ISNULL(b.BetID, 0),
				b.Bettype,
				0 AS hdp1,
				0 AS hdp2,
				modds,
				0 AS OddsType,
				b.Odds,
				b.stake,
				b.actual_stake,
				'' AS Betteam,
				b.Status,
				b.refno,
				b.Transdate,
				b.winlostdate,
				(b.winlost-actual_stake),
				- (b.winlost-actual_stake),
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
				0,
				0,
				b.currency,
				'' AS ShowTime,
				'' AS betcheck,
				'' AS transdesc
			FROM
				bodb_archive.dbo.bettrans_bk AS b WITH (NOLOCK)
				INNER JOIN bodb_archive.dbo.Outright_bk AS m WITH (NOLOCK) ON b.matchid = m.orid
				INNER JOIN dbo.League AS l WITH (NOLOCK) ON m.leagueID = l.leagueID
				INNER JOIN @SportBettype AS sbt ON b.Bettype = sbt.Bettype
			WHERE
				b.winlostdate BETWEEN @fdate AND @TempToDate 
				AND b.custid = @custid 
				AND (@currencyID = 0 OR b.currency = @currencyID ) 
				AND b.ruben = 1 
				AND b.status NOT IN ('VOID', 'REJECT', 'REFUND') 
				AND sbt.ProductID = 1 
				AND sbt.EventType = 2 
				AND b.transid NOT IN (SELECT Transid FROM @TempBetList) --exclude BA tickets

			-- Mix Parlay + System Parlay
			INSERT INTO @BetListByDateMem
			SELECT
				0, --Sporttype
				CASE
					WHEN b.bettype <> 29 THEN b.transid
					ELSE CASE WHEN ISNULL(b.BetID,0)=0 THEN b.transid ELSE betid END
				END AS transid,
				ISNULL(b.BetID, 0),
				b.bettype,
				b.hdp1,
				b.hdp2,
				modds,
				0 AS OddsType,
				b.Odds,
				b.stake,
				b.actual_stake,
				b.betteam,
				b.Status,
				b.refno,
				b.Transdate,
				b.winlostdate,
				(b.winlost-actual_stake),
				- (b.winlost-actual_stake),
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
				0,
				0,
				b.currency,
				'' AS ShowTime,
				ISNULL(b.betcheck, '') AS BetCheck,
				'' AS transdesc
			FROM
				bodb_archive.dbo.bettrans_bk AS b WITH (NOLOCK)
				INNER JOIN @SportBettype AS sbt ON b.Bettype = sbt.Bettype
			WHERE
				b.winlostdate BETWEEN @fdate AND @TempToDate 
				AND b.custid = @custid 
				AND (@currencyID = 0 OR b.currency = @currencyID) 
				AND b.ruben = 1 
				AND b.status NOT IN ('VOID', 'REJECT','REFUND') 
				AND sbt.ProductID = 1 
				AND sbt.EventType = 0 
				AND b.matchid IN (0, 9, 29) --should NOT remove 0 IN archive
				AND b.transid NOT IN (SELECT Transid FROM @TempBetList) --exclude BA tickets
		END
	
		-- Bet trade
		IF @ShowBT = 1
		BEGIN
			INSERT INTO @BetListByDateMem
			SELECT
				m.Sporttype,
				b.TransID,
				ISNULL(ob.bettype,0),
				b.Bettype,
				b.hdp1,
				b.hdp2,
				b.modds,
				b.Oddstype,
				ob.Odds,
				ob.stake,
				b.actual_stake,
				b.betteam,
				b.status,
				b.refno,
				b.Transdate,
				b.winlostdate,
				(b.winlost-b.actual_stake),
				- (b.winlost-b.actual_stake),
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
				m.HomeID,
				m.AwayID,
				m.Betstatus,
				ISNULL(m.isNeutral, CONVERT(BIT,0)) AS IsNeutral,
				0,
				0,
				b.currency,
				'' AS ShowTime,
				b.betcheck,
				'' AS transdesc
			FROM
				bodb_archive.dbo.bettrans_bk AS b WITH (NOLOCK)
				INNER JOIN bodb_archive.dbo.bettrans_bk AS ob WITH (NOLOCK) ON b.refno = ob.transid
				INNER JOIN bodb_archive.dbo.match_BK AS m WITH (NOLOCK) ON b.matchid = m.matchid
				INNER JOIN @SportBettype AS sbt ON b.Bettype = sbt.Bettype
			WHERE
				b.winlostdate BETWEEN @fdate AND @TempToDate 
				AND b.custid = @custid 
				AND (@currencyID = 0 OR b.currency = @currencyID)
				AND b.ruben = 1 
				AND b.status NOT IN ('VOID', 'REJECT', 'REFUND') 
				AND b.bettype IN (901, 902, 903) 
				AND sbt.ProductID = 1 
				AND sbt.EventType = 1
		END

		-- Number Game, Live Casino
		IF @ShowNG = 1 OR @ShowLC = 1
		BEGIN
			INSERT INTO @BetListByDateMem
			SELECT
				m.Sporttype,
				b.TransID,
				ISNULL(b.BetID, 0),
				b.Bettype,
				b.hdp1,
				b.hdp2,
				modds,
				b.Oddstype,
				b.Odds,
				b.stake,
				b.actual_stake,
				b.betteam,
				b.status,
				b.refno,
				b.Transdate,
				b.winlostdate,
				(b.winlost-actual_stake),
				- (b.winlost-actual_stake),
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
				0,
				0,
				b.currency,
				CASE 
					WHEN sbt.ProductID = 4 THEN ISNULL(m.showtime, '') 
					ELSE '' 
				END AS ShowTime,
				'' AS betcheck,
				'' AS transdesc
			FROM
				bodb_archive.dbo.bettrans_bk AS b WITH (NOLOCK)
				INNER JOIN bodb_archive.dbo.match_BK AS m WITH (NOLOCK) ON b.matchid = m.matchid 
				INNER JOIN @SportBettype AS sbt ON b.Bettype = sbt.Bettype
			WHERE
				b.winlostdate BETWEEN @fdate AND @TempToDate 
				AND b.custid = @custid 
				AND (@currencyID = 0 OR b.currency = @currencyID)
				AND sbt.ProductID IN (3, 4)
				AND b.ruben = 1 
				AND b.status NOT IN ('VOID', 'REJECT', 'REFUND')
		END

		-- Virtual Sports
		IF @ShowVS = 1
		BEGIN
			INSERT INTO @BetListByDateMem
			SELECT
				m.Sporttype,
				b.TransID,
				ISNULL(b.BetID, 0),
				b.Bettype,
				b.hdp1, 
				b.hdp2,
				modds,
				b.Oddstype,
				b.Odds,
				b.stake,
				b.actual_stake,
				b.betteam,
				b.status,
				b.refno,
				b.Transdate,
				b.winlostdate,
				(b.winlost-actual_stake),
				- (b.winlost-actual_stake),
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
				0,
				0,
				b.currency,
				CONVERT(NVARCHAR(50), m.kickofftime) AS ShowTime,
				'' AS betcheck,
				'' AS transdesc
			FROM
				bodb_archive.dbo.bettrans_bk AS b WITH (NOLOCK)
				INNER JOIN bodb_archive.dbo.match_BK AS m WITH (NOLOCK) ON b.matchid = m.matchid
				INNER JOIN @SportBettype sbt ON b.Bettype = sbt.Bettype
			WHERE
				b.winlostdate BETWEEN @fdate AND @TempToDate 
				AND b.custid = @custid 
				AND (@currencyID = 0 OR b.currency = @currencyID) 
				AND sbt.ProductID = 5 
				AND sbt.EventType = 1 
				AND b.ruben = 1 
				AND b.status NOT IN ('VOID', 'REJECT', 'REFUND')
			UNION ALL
			SELECT 
				r.sporttype,
				b.transid,
				ISNULL(b.BetID, 0),
				b.Bettype,
				b.hdp1,
				b.hdp2,
				modds,
				b.oddstype,
				b.Odds,
				b.stake,
				b.actual_stake,
				b.betteam,
				b.status,
				b.refno,
				b.Transdate,
				b.winlostdate,
				(b.winlost-actual_stake),
				- (b.winlost-actual_stake),
				b.comm,
				b.playercomm,
				b.Liveindicator,
				b.Livehomescore,
				b.Liveawayscore,
				b.IP,
				r.LeagueID,
				o.EventID MatchID,
				CONVERT(VARCHAR(50),o.RacerNum) MatchCode,
				b.oddsid AS Race,
				o.RacerID HomeID,
				0 AS AwayID,
				r.Betstatus,
				ISNULL(0, CONVERT(BIT,0)) AS IsNeutral,
				0,
				0,
				b.currency,
				CONVERT(VARCHAR(20),r.EventTime) AS showtime,
				'' AS betcheck,
				'' AS transdesc
			FROM bodb_archive.dbo.bettrans_bk AS b WITH (NOLOCK)
				INNER JOIN bodb_Archive.dbo.VSOutright_bk AS o WITH (NOLOCK) ON b.oddsid = o.Orid
				INNER JOIN VSRaceInfo AS r WITH (NOLOCK) ON r.EventID = o.EventID
				INNER JOIN @SportBettype AS sbt ON b.Bettype = sbt.Bettype
			WHERE
				b.winlostdate BETWEEN @fdate AND @TempToDate 
				AND b.custid = @custid 
				AND (@currencyID = 0 OR b.currency = @currencyID)
				AND sbt.ProductID = 5 
				AND sbt.EventType = 3 
				AND b.statusID IN (111, 112, 113)
		END

		-- RNG Casino, Microgaming Live Casino, Microgaming RNG Casino, AG Casino, AllBet, Voidbridge, Fishing World
		IF @ShowCS = 1 OR @ShowMGCLC = 1 OR @ShowMGCRNG = 1 OR @ShowAGC = 1 OR @ShowAB = 1 OR @ShowVB = 1 OR @ShowFW = 1
		BEGIN
			INSERT INTO @BetListByDateMem
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
				b.transid,
				ISNULL(b.betid, 0),
				b.bettype,
				CASE
					WHEN sbt.ProductID = 6 AND sbt.SubProduct = '' THEN b.hdp1
					ELSE 0
				END AS hdp1,
				CASE
					WHEN sbt.ProductID = 6 AND sbt.SubProduct = '' THEN b.hdp2
					ELSE 0
				END AS hdp2,
				CASE
					WHEN sbt.ProductID = 6 AND sbt.SubProduct = '' THEN b.modds
					ELSE 0
				END AS modds,
				CASE
					WHEN sbt.ProductID = 6 AND sbt.SubProduct = '' THEN b.oddstype
					ELSE 0
				END AS Oddstype,
				CASE
					WHEN sbt.ProductID = 6 AND sbt.SubProduct = '' THEN b.Odds
					ELSE 0
				END AS Odds,
				b.stake,
				b.actual_stake,
				CASE
					WHEN sbt.ProductID = 6 AND sbt.SubProduct = '' THEN ISNULL(b.betteam, '')
					ELSE ''
				END AS Betteam,
				b.status,
				b.refno,
				b.transdate,
				b.winlostdate,
				(b.winlost - actual_stake),
				- (b.winlost - actual_stake),
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
				CONVERT(BIT,0) AS IsNeutral,
				0,
				0,
				b.currency,
				'' AS showtime,
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
				bodb_archive.dbo.bettrans_bk AS b WITH (NOLOCK)
				INNER JOIN @SportBettype sbt ON b.Bettype = sbt.Bettype
			WHERE
				b.winlostdate BETWEEN @fdate AND @TempToDate 
				AND b.custid = @custid 
				AND (@currencyID = 0 OR b.currency = @currencyID) 
				AND sbt.ProductID IN (6, 11, 13, 17, 21, 22, 24)
				AND b.ruben = 1 
				AND b.status NOT IN ('VOID', 'REJECT', 'REFUND')
		END

		-- Horse Racing
		IF @ShowRB = 1
		BEGIN
			INSERT INTO @BetListByDateMem
			SELECT
				l.sporttype,
				b.TransID,
				ISNULL(b.BetID, 0),
				b.Bettype,
				b.hdp1,
				b.hdp2,
				modds,
				0 AS OddsType,
				b.Odds,
				b.stake,
				b.actual_stake,
				'' AS Betteam,
				b.Status,
				b.refno,
				b.Transdate,
				b.winlostdate,
				(b.winlost-actual_stake),
				awinlost,
				b.comm,
				b.playercomm,
				0 AS LiveIndicator,
				b.LiveHomescore,
				b.LiveAwayscore,
				b.IP,
				m.LeagueID,
				m.OrId,
				m.MatchCode,
				m.GroupMatch,--Race
				m.TeamID, --HomeID
				0, --AwayID
				0, --Betstatus
				CONVERT(BIT,0) AS IsNeutral,
				b.virtualrate,
				ISNUMERIC(m.programID),
				b.currency,
				'' AS ShowTime,
				'' AS betcheck,
				'' AS transdesc
			FROM
				bodb_archive.dbo.bettrans_bk AS b WITH (NOLOCK)
				INNER JOIN bodb_archive.dbo.Outright_bk AS m WITH (NOLOCK) ON b.matchid = m.orid
				INNER JOIN dbo.League AS l WITH (NOLOCK) ON m.leagueID = l.leagueID
				INNER JOIN @SportBettype AS sbt ON b.Bettype = sbt.Bettype
			WHERE
				b.winlostdate BETWEEN @fdate AND @TempToDate 
				AND b.custid = @custid 
				AND (@currencyID = 0 OR b.currency = @currencyID ) 
				AND b.ruben = 1 
				AND b.status NOT IN ('VOID','REJECT','REFUND') 
				AND sbt.ProductID = 2
		END

		-- Keno
		IF @ShowKN = 1
		BEGIN
			INSERT INTO @BetListByDateMem
			SELECT
				202 AS Sporttype,
				b.transid,
				ISNULL(b.BetID, 0),
				b.Bettype,
				0 AS hdp1,
				0 AS hdp2,
				b.modds,
				b.Oddstype,
				b.Odds,
				b.stake,
				b.actual_stake,
				ChoiceID AS betteam,
				b.status,
				b.refno,
				b.Transdate,
				b.winlostdate,
				(b.winlost-actual_stake),
				- (b.winlost-actual_stake),
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
				0,
				0,
				b.currency,
				'' AS showtime,
				'' AS betcheck,
				'' AS transdesc
			FROM
				bodb_archive.dbo.bettrans_bk AS b WITH (NOLOCK)
				CROSS APPLY dbo.f_ParseTransDesc(b.transdesc, b.bettype)
				INNER JOIN @SportBettype AS sbt ON b.Bettype = sbt.Bettype
			WHERE
				b.winlostdate BETWEEN @fdate AND @TempToDate 
				AND b.custid = @custid 
				AND (@currencyID = 0 OR b.currency = @currencyID) 
				AND sbt.ProductID = 8 
				AND b.ruben = 1 
				AND b.status NOT IN ('VOID', 'REJECT', 'REFUND')
		END

		-- Colossus Bets
		IF @ShowCB = 1
		BEGIN
			INSERT INTO @BetListByDateMem
			SELECT
				204 AS SportType,
				b.transid,
				ISNULL(b.betid, 0),
				b.bettype,
				0 AS Hdp1,
				0 AS Hdp2,
				0 AS MOdds,
				0 AS OddsType,
				0 AS Odds,
				b.stake,
				b.actual_stake,
				'' AS BetTeam,
				b.status,
				b.refno,
				b.transdate,
				b.winlostdate,
				(b.winlost - actual_stake) AS WinLost,
				0 AS LicenseeWL,
				b.comm,
				b.playercomm,
				0 AS LiveIndicator,
				0 AS LiveHomeScore,
				0 AS LiveAwayScore,
				b.ip,
				0 AS LeagueId,
				0 AS MatchId,
				'' AS MatchCode,
				'' AS Race,
				0 AS HomeId,
				0 AS AwayId,
				0 AS Betstatus,
				CONVERT(BIT, 0) AS IsNeutral,
				0 AS VirtualRate,
				0 AS IsShowOTExRate,
				b.currency,
				'' AS ShowTime,
				ISNULL(bm.betcheck, '') AS BetCheck,
				'' AS transdesc
			FROM
				bodb_Archive.dbo.bettrans_bk AS b WITH (NOLOCK)
				INNER JOIN @SportBettype sbt ON b.bettype = sbt.Bettype
				LEFT JOIN bodb_Archive.dbo.bettransm AS bm WITH (NOLOCK) ON b.refno = bm.refno AND bm.bettype = 18001
			WHERE
				b.winlostdate BETWEEN @fdate AND @TempToDate
				AND b.custid = @custid
				AND (@currencyID = 0 OR b.currency = @currencyID )
				AND b.statusID IN (111, 112, 113)
				AND sbt.ProductID = 15
		END
	END

	IF @ShowBT = 1
	BEGIN
		UPDATE betList
		SET betList.comm = CASE WHEN betList.Bettype = 902 THEN commBetList.comm ELSE betList.comm END
		FROM @BetListByDateMem AS betList
			INNER JOIN @BetListByDateMem AS commBetList ON betList.RefNO = commBetList.RefNO
		WHERE betList.Sporttype = 1 
			AND betList.Bettype IN (901, 902)
			AND commBetList.Bettype = 903

		DELETE @BetListByDateMem WHERE Sporttype = 1 AND Bettype = 903
	END

	--@currency
	SELECT CurrencyID
		,LicenseeID
	INTO #Currency
	FROM DBLIC.bodb_licensee.dbo.CurrencyUser WITH (NOLOCK)
	WHERE usrID = @userID 
		AND LicenseeID = @LicenseeID 
		AND SystemID = 1
		AND isActive = 1

	SELECT * 
	INTO #TempExchange 
	FROM Lrf_f_GetExchangeDaily(@FDate, @TDate)
	WHERE exchangeid IN 
	(
		SELECT DISTINCT lc.Currency
		FROM OPENQUERY(DBLIC, 'SELECT * FROM bodb_licensee.dbo.f_SelLicenseeCust(0)') lc
			INNER JOIN #currency c ON lc.LicenseeID = c.LicenseeID AND lc.Currency = c.CurrencyID 
	)
	---------------------------------------
	DROP TABLE #currency
	---------------------------------------

	--exclude draw for no draw option (2)
	DELETE FROM @BetListByDateMem
	WHERE @drawfilter = 2 AND status = 'DRAW' AND ABS(modds) <> 0.25

	DECLARE @RowStart INT,
		@RowEnd INT

	SELECT @PageIndex = @PageIndex - 1, 
		@RowStart = @PageSize * @PageIndex + 1, 
		@RowEnd = @RowStart + @PageSize - 1

	SELECT
		@TotalRows		= COUNT(b.TransId),
		@SumWinlost		= SUM(ISNULL(b.WinLost, 0)),
		@SumLicenseeWL	= SUM(ISNULL(b.LicenseeWL, 0)),
		@SumComm		= SUM(ISNULL(b.Comm, 0)),
		@SumPlayerComm	= SUM(ISNULL(b.PlayerComm, 0)),
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
	FROM @BetListByDateMem AS b
		INNER JOIN #TempExchange AS e ON e.ExchangeDate = b.winlostdate AND e.exchangeid = b.currency

	SELECT A.*
	FROM
		(
		SELECT
			ROW_NUMBER() OVER (ORDER BY TransID) AS RowNum,
			d.*,
			-- MYR
			d.Stake			* e.MYR	AS StakeMYR,
			d.Actual_Stake	* e.MYR	AS actual_stakeMYR,
			d.WinLost		* e.MYR	AS WinlostMYR,
			d.LicenseeWL	* e.MYR	AS LicenseeWLMYR,
			d.Comm			* e.MYR	AS commMYR,
			d.PlayerComm	* e.MYR	AS playercommMYR,
			-- USD
			d.Stake			* e.USD	AS StakeUSD,
			d.Actual_Stake	* e.USD	AS actual_stakeUSD,
			d.WinLost		* e.USD	AS WinlostUSD,
			d.LicenseeWL	* e.USD	AS LicenseeWLUSD,
			d.Comm			* e.USD	AS commUSD,
			d.PlayerComm	* e.USD	AS playercommUSD,
			-- EUR
			d.Stake			* e.EUR	AS StakeEUR,
			d.Actual_Stake	* e.EUR	AS actual_stakeEUR,
			d.WinLost		* e.EUR	AS WinlostEUR,
			d.LicenseeWL	* e.EUR	AS LicenseeWLEUR,
			d.Comm			* e.EUR	AS commEUR,
			d.PlayerComm	* e.EUR	AS playercommEUR,
			-- GBP
			d.Stake			* e.GBP	AS StakeGBP,
			d.Actual_Stake	* e.GBP	AS actual_stakeGBP,
			d.WinLost		* e.GBP	AS WinlostGBP,
			d.LicenseeWL	* e.GBP	AS LicenseeWLGBP,
			d.Comm			* e.GBP	AS commGBP,
			d.PlayerComm	* e.GBP	AS playercommGBP
		FROM @BetListByDateMem d
			INNER JOIN #TempExchange e
				ON e.ExchangeDate =  d.WinLostDate AND e.exchangeid = d.Currency
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
				FROM @BetListByDateMem AS b
					INNER JOIN @SportBettype AS sbt ON b.BetType = sbt.Bettype
				WHERE sbt.ProductID = 2)
	BEGIN
		IF @tdate > @MoveBetsDay
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
				INNER JOIN @BetListByDateMem AS b ON bm.refno = b.transid
				INNER JOIN #TempExchange AS e ON e.ExchangeDate = b.Winlostdate AND e.exchangeid = b.currency
				INNER JOIN @SportBettype AS sbt ON b.Bettype = sbt.Bettype
				INNER JOIN @SportBettype AS sbtm ON bm.bettype = sbtm.Bettype
			WHERE bm.custid = @CustId
				AND sbt.ProductID = 2
				AND sbtm.ProductID = 2
		END

		IF @fdate <= @MoveBetsDay
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
				INNER JOIN @BetListByDateMem AS b ON bm.refno = b.transid
				INNER JOIN #TempExchange AS e ON e.ExchangeDate = b.Winlostdate AND e.exchangeid = b.currency
				INNER JOIN @SportBettype AS sbt ON b.Bettype = sbt.Bettype
				INNER JOIN @SportBettype AS sbtm ON bm.bettype = sbtm.Bettype
			WHERE bm.custid = @CustId
				AND sbt.ProductID = 2
				AND sbtm.ProductID = 2
		END

		IF @fdate < @BalanceUpDay
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
				INNER JOIN @BetListByDateMem AS b ON bm.refno = b.transid
				INNER JOIN #TempExchange AS e ON e.ExchangeDate = b.winlostdate AND e.exchangeid = b.currency
				INNER JOIN @SportBettype AS sbt ON b.Bettype = sbt.Bettype
				INNER JOIN @SportBettype AS sbtm ON bm.bettype = sbtm.Bettype
			WHERE bm.custid = @CustId
				AND sbt.ProductID = 2
				AND sbtm.ProductID = 2
		END
	END

	-- Live Casino
	IF EXISTS (	SELECT 1
				FROM @BetListByDateMem AS b
					INNER JOIN @SportBettype AS sbt ON b.BetType = sbt.Bettype
				WHERE sbt.ProductId = 4 )
	BEGIN
		IF @tdate > @MoveBetsDay
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
				INNER JOIN @BetListByDateMem AS b ON bg.refno = b.refno
				INNER JOIN #TempExchange AS e ON e.ExchangeDate = b.winlostdate AND e.exchangeid = b.currency
				INNER JOIN @SportBettype AS sbt ON b.Bettype = sbt.Bettype
				INNER JOIN @SportBettype AS sbtg ON bg.bettype = sbtg.Bettype
			WHERE bg.custid = @CustId
				AND sbt.ProductID = 4
				AND sbtg.ProductID = 4
		END

		IF @fdate <= @MoveBetsDay
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
				INNER JOIN @BetListByDateMem AS b ON bg.refno = b.refno
				INNER JOIN #TempExchange AS e ON e.ExchangeDate = b.winlostdate AND e.exchangeid = b.currency
				INNER JOIN @SportBettype AS sbt ON b.Bettype = sbt.Bettype
				INNER JOIN @SportBettype AS sbtg ON bg.bettype = sbtg.Bettype
			WHERE bg.custid = @CustId
				AND sbt.ProductID = 4
				AND sbtg.ProductID = 4
		END

		IF @fdate < @BalanceUpDay
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
			FROM bodb_archive.dbo.bettransG AS bg WITH (NOLOCK)
				INNER JOIN @BetListByDateMem AS b ON bg.refno = b.refno
				INNER JOIN #TempExchange AS e ON e.ExchangeDate = b.winlostdate AND e.exchangeid = b.currency
				INNER JOIN @SportBettype AS sbt ON b.Bettype = sbt.Bettype
				INNER JOIN @SportBettype AS sbtg ON bg.bettype = sbtg.Bettype
			WHERE bg.custid = @CustId
				AND sbt.ProductID = 4
				AND sbtg.ProductID = 4
		END
	END

	-- Virtual Sports
	IF EXISTS (	SELECT 1
				FROM @BetListByDateMem AS b
					INNER JOIN @SportBettype AS sbt ON b.bettype = sbt.Bettype
				WHERE sbt.ProductId = 5 AND sbt.EventType = 3)
	BEGIN
		IF @tdate > @MoveBetsDay
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
				INNER JOIN @BetListByDateMem AS b ON bm.refno = b.refno
				INNER JOIN #TempExchange AS e ON e.ExchangeDate = b.winlostdate AND e.exchangeid = b.currency
				INNER JOIN @SportBettype AS sbt ON b.Bettype = sbt.Bettype
				INNER JOIN @SportBettype AS sbtm ON bm.bettype = sbtm.Bettype
			WHERE bm.custid = @CustId
				AND sbt.ProductID = 5
				AND sbt.EventType = 3
				AND sbtm.ProductID = 5
				AND sbtm.EventType = 3
		END

		IF @fdate <= @MoveBetsDay
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
				INNER JOIN @BetListByDateMem AS b ON bm.refno = b.refno
				INNER JOIN #TempExchange AS e ON e.ExchangeDate = b.winlostdate AND e.exchangeid = b.currency
				INNER JOIN @SportBettype AS sbt ON b.Bettype = sbt.Bettype
				INNER JOIN @SportBettype AS sbtm ON bm.bettype = sbtm.Bettype
			WHERE bm.custid = @CustId
				AND sbt.ProductID = 5
				AND sbt.EventType = 3
				AND sbtm.ProductID = 5
				AND sbtm.EventType = 3
		END

		IF @fdate < @BalanceUpDay
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
				INNER JOIN @BetListByDateMem AS b ON bm.refno = b.refno
				INNER JOIN #TempExchange AS e ON e.ExchangeDate = b.winlostdate AND e.exchangeid = b.currency
				INNER JOIN @SportBettype AS sbt ON b.Bettype = sbt.Bettype
				INNER JOIN @SportBettype AS sbtm ON bm.bettype = sbtm.Bettype
			WHERE bm.custid = @CustId
				AND sbt.ProductID = 5
				AND sbt.EventType = 3
				AND sbtm.ProductID = 5
				AND sbtm.EventType = 3
		END
	END 

	SELECT * FROM @BettransDetail 
	ORDER BY RefNo,Bettype

	DROP TABLE #TempExchange
	/*
		[Lrf_BetList_SelWinloss_Mem]
		@CustID			=1265745,
		@FromDate		='2012-09-01',
		@ToDate			='2012-09-10',
		@MoveBetsDay	='2012-09-03',
		@BalanceUpDay	='2012-09-05',
		@ShowSB			 = 1,
		@ShowRB			 = 1,
		@ShowNG			 = 1,
		@ShowBA			 = 1,
		@ShowLC			 = 1,
		@ShowVS			 = 1,
		@ShowCS			 = 1,
		@ShowMGCLC		 = 1,
		@ShowMGCRNG		 = 1,
		@ShowAGC		 = 1,
		@ShowAB			 = 1,
		@ShowVB			 = 1,
		@ShowFW			 = 1,
		@ShowCB			 = 1
	*/
END




GO
GRANT EXECUTE ON [dbo].[Lrf_BetList_SelWinloss_Mem] TO [bodbLicenseeNet] 
GO
GRANT VIEW DEFINITION ON [dbo].[Lrf_BetList_SelWinloss_Mem] TO [vnteam] 