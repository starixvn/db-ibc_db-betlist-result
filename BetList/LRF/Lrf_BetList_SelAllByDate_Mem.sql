USE [bodb02]
GO
/****** Object:  StoredProcedure [dbo].[Lrf_BetList_SelAllByDate_Mem_xtest]    Script Date: 7/7/2015 2:27:28 PM ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
ALTER PROCEDURE [dbo].[Lrf_BetList_SelAllByDate_Mem]
	@AgentList			VARCHAR(MAX),
	@CustId				INT			= NULL,
	@FromDate			DATETIME,
	@ToDate				DATETIME,
	@Username			VARCHAR(50) = NULL, -- for API
	@PageSize			INT			= 1000,
	@PageIndex			INT			= 1,
	-- check for showing product
	@ShowSB				BIT = 0,
	@ShowRB				BIT = 0,
	@ShowNG				BIT = 0,
	@ShowBA				BIT = 0,
	@ShowLC				BIT = 0,
	@ShowVS				BIT = 0,
	@ShowCS				BIT = 0, -- RNG Casino
	@ShowKN				BIT = 0, -- Keno
	@ShowMGCLC			BIT = 0, -- Microgaming Live Casino
	@ShowCB				BIT = 0, -- Colossus Bets
	@ShowMGCRNG			BIT = 0, -- Microgaming RNG Casino
	@ShowAGC			BIT = 0, -- AG Casino
	@ShowAB				BIT = 0, -- AllBet
	@ShowVB				BIT = 0, -- Voidbridge
	@ShowFW				BIT = 0, -- Fishing World
	@ShowBT				BIT = 0, -- Bet Trade
	@ShowCO				BIT = 0, -- Cash Out
	-- output info
	@SumWinLost			MONEY			= 0 OUTPUT,
	@SumLicenseeWL		MONEY			= 0 OUTPUT,
	@SumComm			MONEY			= 0 OUTPUT,
	@SumPlayerComm		MONEY			= 0 OUTPUT,
	@SumWinLostUSD		MONEY			= 0 OUTPUT,
	@SumLicenseeWLUSD	MONEY			= 0 OUTPUT,
	@SumCommUSD			MONEY			= 0 OUTPUT,
	@SumPlayerCommUSD	MONEY			= 0 OUTPUT,
	@SumWinLostEUR		MONEY			= 0 OUTPUT,
	@SumLicenseeWLEUR	MONEY			= 0 OUTPUT,
	@SumCommEUR			MONEY			= 0 OUTPUT,
	@SumPlayerCommEUR	MONEY			= 0 OUTPUT,
	@SumWinLostGBP		MONEY			= 0 OUTPUT,
	@SumLicenseeWLGBP	MONEY			= 0 OUTPUT,
	@SumCommGBP			MONEY			= 0 OUTPUT,
	@SumPlayerCommGBP	MONEY			= 0 OUTPUT,
	@TotalRows			INT				= 0 OUTPUT,
	@ErrorCode			INT				= 0 OUTPUT,
	@ErrorMsg			NVARCHAR(100)	= '' OUTPUT
AS

/*
	Created: Henry@20101209
	Task: Bet List
	DB: DBEXT.bodb02
	Original [Age_BetList_SelAllByDate_Mem]
	Revisions:
		- 20110214@Jacob: Add column discount IN the result SET
		- 20110303@Henry: suppport bASed currency
		- 20110408@Amy: Change function to get Odds value AND odds type
						Show odds value AND odds type for Number game
		- 20110712@Henry: Add column LicenseeWL
		- 20110729@Henry: offer 3 new bettypes for Number Game + Combination Mix Parlay
		- 20111128@Henry: Compare Checktime and CURRENT_TIMESTAMP to shDow waiting or running status
		- 20111208@Jim: Chang condition bettype < 31
		- 20111229@Jim: change the way to get odds/oddstype/betteam to web dev
		- 20120214@Jim: change table ExchangeDaily by function Lrf_f_GetExchangeDaily
		- 20120319@Henry: show main transid for sub-ticket of system parlay 
		- 20120614@Jim: optimize code
		- 20120706@Jim: get sporttype for Outright
		- 20120711@Jim: get value for hdp1, hdp2
		- 20120724@Jim: add player commision value
		- 20120817@Jim: add live casino
		- 20120912@Jim: add virtual sport
		- 20121115@Henry: Only Sportsbook needs to exclude BA
		- 201300426@Scott: Support RNG Casino and Bingo
		- 20130514@Jim: Restrict permission of Licensee Users by currency
		- 20130716@Jim: update matchid for RNG Casino and Bingo
		- 20130903@Jim: offer VHR
		- 20140305@Hannah: offer Keno
		- 20140630@Hannah: offer BetRadar and Sporting Solution
		- 20140908@Jim: restrict Virtual Horse Racing bettype (hot fix  #22012)
		- 20150130@Winnie: Add base currency GBP
		- 20150403@Bobby: Apply sporttype matrix & #32844 new 60 bettypes - betradar phase 2
		- 20150605@Edward: Support Microgaming
		- 20150608@Edward: Support Bet Trade
		- 20150729@Edward: Return betcheck for Microgaming
		- 20150828@Edward: Return refNo value instead of '' for BetTrade tickets
		- 20150828@Edward: Update Odds and Stake in the same time insert to temporary table
		- 20150917@Kos: Support Microgaming RNG Casino
		- 20150922@Kos: Support AG Casino
		- 20151028@Kos: Change ProductId, SportType of Microgaming RNG Casino
		- 20151203@Kos: Change odds, modds data type from SMALLMONEY to MONEY [Redmine: #48660]
		- 20151224@Jim: Fix bug []Redmine: #49885]
		- 20151228@Kos: Support RNG Casino Single Wallet [Redmine: #48958]
		- 20160202@Kos: Support PH All In One 1.2 [#Redmine: 50897]
		- 20160216@Kos: Support yesterday running ticket [Redmine: #52277]
		- 20160406@Kos: Support Voidbridge [#Redmine: 54925]
		- 20160413@Kos: Support Combo Parlay [#Redmine: 55282]
		- 20160714@Kos: Remove Bingo and change to use inline function for SportBettypeMatrix
		- 20160727@Kos: Support AllBet [#Redmine: 61066]
		- 20160801@Kos: Exclude bet type 904 [#Redmine: 58978]
		- 20160913@Kos: Support Colossus Bets [#Redmine: 63785]
		- 20161006@Kos: Add product bet type range for sub tickets [Redmine: #65045]
		- 20161114@Kos: Support Fishing World [#Redmine: 66737]
		- 20170303@Kos: Support KickOffTime for Virtual Soccer and Virtual Tennis [#Redmine: 71906]
		- 20170307@Kos: Support sub licensees [#Redmine: 71679]
		- 20170331@Kos: Support CashOut [#Redmine: 71963]
*/

BEGIN
	SET NOCOUNT ON;

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
	
	DECLARE @Recommend	INT,
		@Today			SMALLDATETIME,
		@Yesterday		SMALLDATETIME

	SELECT @Today = DATEADD(DAY, DATEDIFF(DAY, 0, GETDATE()), 0),
		@Yesterday = DATEADD(DAY, DATEDIFF(DAY, 1, GETDATE()), 0)
	
	IF @CustId IS NULL
	BEGIN
		SELECT @CustId = custid 
		FROM dbo.customer WITH (NOLOCK)
		WHERE username = @username
	END

	SELECT @Recommend = Recommend
		, @UserName = Username
	FROM dbo.custinfo WITH (NOLOCK)
	WHERE custid = @CustId
		AND currency IN (SELECT DISTINCT Currency FROM @TempAg)

	IF @CustId IS NULL OR @UserName IS NULL
	BEGIN
		SELECT @ErrorCode	= 100
			, @ErrorMsg		= 'The customer was not found.'
		RETURN;
	END
	
	CREATE TABLE #BetListSelAllByDateMem (
		Username		NVARCHAR(50),
		SportType		INT,
		BetType			SMALLINT,
		RefNo			NVARCHAR(50),
		TransId			BIGINT,
		BetId			BIGINT,
		MatchCode		NVARCHAR(50),
		MatchId			INT,
		Race			NVARCHAR(50),
		HomeId			INT,
		AwayId			INT,
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
		Discount		DECIMAL(9,8),
		TransDate		DATETIME,
		WinLostDate		DATETIME,
		BetTeam			NVARCHAR(50),
		LeagueId		INT,
		LiveIndicator	BIT,
		LiveHomeScore	SMALLINT,
		LiveAwayScore	SMALLINT,
		Ip				NVARCHAR(15),
		BetStatus		NVARCHAR(50),
		IsNeutral		BIT,
		OddsType		INT NULL,
		Currency		SMALLINT,
		ShowTime		NVARCHAR(50),
		BetCheck		NVARCHAR(50),
		TransDesc		NVARCHAR(300),
		BetdaqId		BIGINT,
		ExtraInfo		VARCHAR(1000),
		OriginalStake	MONEY,
		OriginalBetType	SMALLINT
	)

	CREATE TABLE #TempBATicket (
		BetType			INT,
		RefNo			BIGINT,
		TransId			BIGINT,
		BetId			BIGINT,
		Hdp1			SMALLMONEY,
		Hdp2			SMALLMONEY,
		Odds			MONEY,
		Modds			MONEY,
		Status			NVARCHAR(10),
		Stake			MONEY,
		Actual_Stake	MONEY,
		WinLost			MONEY,
		LicenseeWL		MONEY,
		Comm			MONEY,
		PlayerComm		MONEY,
		Discount		DECIMAL(9,8),
		TransDate		DATETIME,
		WinLostDate		DATETIME,
		BetTeam			NVARCHAR(20),
		LiveIndicator	BIT,
		LiveHomeScore	SMALLINT,
		LiveAwayScore	SMALLINT,
		Ip				NVARCHAR(50),
		OddsType		TINYINT,
		Currency		INT,
		MatchId			INT,
		CustId			INT,
		BetCheck		NVARCHAR(50),
		TransDesc		NVARCHAR(300),
		BetdaqId		BIGINT,
		ExtraInfo		VARCHAR(1000),
		OriginalStake	MONEY,
		OriginalBetType	SMALLINT
	)
	
	-- filer bettypes by sporttype
	DECLARE @SportBettype TABLE (ProductID TINYINT, Bettype SMALLINT, EventType TINYINT, SubProduct VARCHAR(500))

	DECLARE @IsTest BIT = 0

	SELECT @IsTest = dbo.f_CheckSPVersion(@@PROCID)

	INSERT INTO @SportBettype
	SELECT ProductID, BetType, EventType, SubProduct
	FROM dbo.f_SportBettypeMatrix_Sel (0, 0, 0, 2, '', '', @IsTest)
	WHERE ProductID <= 6 OR ProductID IN (8, 11, 13, 15, 17, 21, 22, 24, 25)

	DELETE @SportBettype
	WHERE Bettype IN (904, 914)

	IF @ShowBT = 0
	BEGIN
		DELETE @SportBettype
		WHERE ProductID = 1 AND Bettype IN (901, 902, 903)
	END

	DELETE FROM @SportBettype
	WHERE (ProductID	= CASE WHEN @ShowSB	= 0 AND @ShowBA = 0 THEN 1 END AND Bettype NOT IN (901, 902, 903))
		OR ProductID	= CASE WHEN @ShowRB		= 0 THEN 2 END
		OR ProductID	= CASE WHEN @ShowNG		= 0 THEN 3 END
		OR ProductID	= CASE WHEN @ShowLC		= 0 THEN 4 END
		OR ProductID	= CASE WHEN @ShowVS		= 0 THEN 5 END
		OR ProductID	= CASE WHEN @ShowCS		= 0 THEN 6 END
		OR ProductID	= CASE WHEN @ShowKN		= 0 THEN 8 END
		OR ProductID	= CASE WHEN @ShowAGC	= 0 THEN 11 END
		OR ProductID	= CASE WHEN @ShowMGCLC	= 0 THEN 13 END
		OR ProductID	= CASE WHEN @ShowCB		= 0 THEN 15 END
		OR ProductID	= CASE WHEN @ShowMGCRNG	= 0 THEN 17 END
		OR ProductID	= CASE WHEN @ShowAB		= 0 THEN 21 END
		OR ProductID	= CASE WHEN @ShowVB		= 0 THEN 22 END
		OR ProductID	= CASE WHEN @ShowFW		= 0 THEN 24 END
		OR ProductID	= CASE WHEN @ShowCO		= 0 THEN 25 END
	-- end filer bettypes by sporttype

	-- BA tickets
	INSERT INTO #TempBATicket
	SELECT
		b.bettype,
		b.refno,
		b.transid,
		ISNULL(b.betid, 0),
		CONVERT(FLOAT, b.hdp1) AS hdp1,
		CONVERT(FLOAT, b.hdp2) AS hdp2,
		b.odds,
		b.modds,
		CASE 
			WHEN b.status = 'running' AND ISNULL(b.SecAcceptFlag, 0) = 1 
				AND ISNULL(b.checktime, CURRENT_TIMESTAMP) > CURRENT_TIMESTAMP THEN 'waiting'
			ELSE b.status
		END AS status,
		b.stake,
		b.actual_stake,
		(winlost-actual_stake) AS WinLost,
		0 AS LicenseeWL,
		b.comm,
		b.playercomm,
		b.discount,
		b.transdate,
		b.winlostdate,
		b.betteam,
		b.liveindicator,
		b.livehomescore,
		b.liveawayscore,
		b.ip,
		b.oddstype,
		b.currency,
		b.matchid,
		b.custid,
		b.betcheck,
		ISNULL(b.transdesc, '') AS transdesc,
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
		END AS OriginalBetType
	FROM 
		dbo.bettrans AS b WITH (NOLOCK)
		INNER JOIN bodb_Licensee.dbo.LicenseeBATransaction AS BA WITH (NOLOCK) ON b.transid = BA.transid
		INNER JOIN @SportBettype AS sbt ON b.bettype = sbt.Bettype
	WHERE b.custid = @CustID
		AND b.recommend = @Recommend
		AND sbt.ProductId = 1
		AND b.transdate >= @FromDate AND b.transdate <= @ToDate
		AND b.bettype NOT IN (901, 902, 903)

	IF @ShowBA = 1
	BEGIN
		-- Sportsbook
		INSERT INTO #BetListSelAllByDateMem
		SELECT 
			@UserName AS UserName,
			m.sporttype,
			b.bettype,
			b.refno,
			b.transid,
			b.BetID,
			m.matchcode,
			m.matchid,
			'' AS Race,
			m.homeID,
			m.awayID,
			CONVERT(FLOAT, b.hdp1) AS hdp1,
			CONVERT(FLOAT, b.hdp2) AS hdp2,
			b.odds,
			b.modds,
			b.status,
			b.stake,
			b.actual_stake,
			b.winlost,
			b.LicenseeWL,
			b.comm,
			b.playercomm,
			b.discount,
			b.transdate,
			b.winlostdate,
			b.betteam,
			m.leagueID,
			b.liveindicator,
			b.livehomescore,
			b.liveawayscore,
			b.Ip,
			m.betstatus,
			ISNULL(m.isNeutral, CONVERT(BIT,0)) AS IsNeutral,
			b.Oddstype,
			b.currency,
			'' AS ShowTime,
			b.betcheck,
			b.transdesc,
			b.BetdaqId,
			b.ExtraInfo,
			b.OriginalStake,
			b.OriginalBetType
		FROM 
			#TempBATicket AS b
			INNER JOIN dbo.match AS m WITH (NOLOCK) ON b.matchid = m.matchid
			INNER JOIN @SportBettype AS sbt ON b.bettype = sbt.Bettype
		WHERE sbt.ProductID = 1 AND sbt.EventType = 1

		-- Outright
		INSERT INTO #BetListSelAllByDateMem
		SELECT
			@UserName,
			l.sporttype,
			b.bettype,
			b.refno,
			b.transid,
			b.BetId,
			m.matchcode,
			b.matchid,
			m.GroupMatch AS Race,
			m.teamID AS homeID,
			0 AS awayID,
			CONVERT(FLOAT, b.hdp1) AS hdp1,
			CONVERT(FLOAT, b.hdp2) AS hdp2,
			b.odds,
			b.modds,
			b.status,
			b.stake,
			b.actual_stake,
			b.winlost,
			b.LicenseeWL,
			b.comm,
			b.playercomm,
			b.discount,
			b.transdate,
			b.winlostdate,
			'' AS Betteam,
			m.leagueID,
			0 AS liveindicator,
			b.livehomescore,
			b.liveawayscore,
			b.Ip,
			'' betstatus,
			CONVERT(BIT,0) AS IsNeutral,
			0 AS OddsType,
			b.currency,
			'' AS ShowTime,
			'' AS betcheck,
			'' AS transdesc,
			-1 AS BetdaqId,
			'' AS ExtraInfo,
			0 AS OriginalStake,
			0 AS OriginalBetType
		FROM
			#TempBATicket AS b
			INNER JOIN dbo.outright AS m WITH (NOLOCK) ON b.matchid = m.orid
			INNER JOIN dbo.league AS l WITH (NOLOCK) ON m.leagueID = l.leagueID
			INNER JOIN @SportBettype AS sbt ON b.bettype = sbt.Bettype
		WHERE sbt.ProductID = 1 AND sbt.EventType = 2

		-- Mix Parlay & System Parlay
		INSERT INTO #BetListSelAllByDateMem
		SELECT
			@UserName,
			0 AS sporttype,
			b.bettype,
			CONVERT(NVARCHAR(20), b.refno) AS refno,
			CASE
				WHEN (ISNULL(b.BetId, 0) = 0 OR b.bettype = 9) THEN b.transid
				ELSE betid
			END AS transid,
			ISNULL(b.BetID,0),
			'' AS matchcode,
			b.matchid,
			'' AS Race,
			0 AS homeID,
			0 AS awayID,
			CONVERT(FLOAT, b.hdp1) AS hdp1,
			CONVERT(FLOAT, b.hdp2) AS hdp2,
			b.odds,
			b.modds,
			b.status,
			b.stake,
			b.actual_stake,
			b.winlost,
			b.LicenseeWL,
			b.comm,
			b.playercomm,
			b.discount,
			b.transdate,
			b.winlostdate,
			b.betteam,
			0 AS leagueID,
			b.liveindicator,
			b.livehomescore,
			b.liveawayscore,
			b.Ip,
			'' AS betstatus,
			CONVERT(BIT,0) AS IsNeutral,
			0 AS OddsType,
			b.currency,
			'' AS ShowTime,
			ISNULL(b.betcheck, '') AS BetCheck,
			'' AS transdesc,
			-1 AS BetdaqId,
			'' AS ExtraInfo,
			0 AS OriginalStake,
			0 AS OriginalBetType
		FROM #TempBATicket AS b
			INNER JOIN @SportBettype AS sbt ON b.bettype = sbt.Bettype
		WHERE sbt.ProductID = 1 AND sbt.EventType = 0
	END

	IF @ShowSB = 1
	BEGIN
		-- Single bet
		INSERT INTO #BetListSelAllByDateMem
		SELECT
			@UserName,
			m.sporttype,
			b.bettype,
			b.refno,
			b.transid,
			ISNULL(b.betid, 0),
			m.matchcode,
			m.matchid,
			'' AS Race,
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
			(winlost-actual_stake) AS WinLost,
			- (b.winlost-b.actual_stake) AS LicenseeWL,
			b.comm,
			b.playercomm,
			b.discount,
			b.transdate,
			b.winlostdate,
			b.betteam,
			m.leagueID,
			b.liveindicator,
			b.livehomescore,
			b.liveawayscore,
			b.ip,
			m.betstatus,
			ISNULL(m.isNeutral, CONVERT(BIT,0)) AS IsNeutral,
			b.oddstype,
			b.currency,
			'' AS ShowTime,
			CASE 
				WHEN b.bettype IN (216, 217) THEN b.betcheck
				ELSE ''
			END AS betcheck,
			ISNULL(b.transdesc, '') AS transdesc,
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
			END AS OriginalBetType
		FROM
			dbo.bettrans AS b WITH (NOLOCK)
			INNER JOIN dbo.match AS m WITH (NOLOCK) ON b.matchid = m.matchid
			INNER JOIN @SportBettype AS sbt ON b.bettype = sbt.Bettype
		WHERE b.custid = @CustID
			AND b.recommend = @Recommend
			AND b.matchid > 0
			AND sbt.ProductID = 1
			AND sbt.EventType = 1
			AND b.transid NOT IN (SELECT TransId FROM #TempBATicket)
			AND b.transdate >= @FromDate AND b.transdate <= @ToDate
			AND b.bettype NOT IN (901, 902, 903)

		-- Outright
		INSERT INTO #BetListSelAllByDateMem
		SELECT
			@UserName,
			l.sporttype,
			b.bettype,
			b.refno,
			b.transid,
			ISNULL(b.betid, 0),
			m.matchcode,
			b.matchid,
			m.GroupMatch AS Race,
			m.teamID AS homeID,
			0 AS awayID,
			CONVERT(FLOAT, b.hdp1) AS hdp1,
			CONVERT(FLOAT, b.hdp2) AS hdp2,
			b.odds,
			b.modds,
			b.status,
			b.stake,
			b.actual_stake,
			(winlost-actual_stake) AS WinLost,
			 - (b.winlost-b.actual_stake) AS LicenseeWL,
			b.comm,
			b.playercomm,
			b.discount,
			b.transdate,
			b.winlostdate,
			'' AS Betteam,
			m.leagueID,
			0 AS liveindicator,
			b.livehomescore,
			b.liveawayscore,
			b.ip,
			'' betstatus,
			CONVERT(BIT,0) AS IsNeutral,
			0 AS OddsType,
			b.currency,
			'' AS ShowTime,
			'' AS betcheck,
			'' AS transdesc,
			-1 AS BetdaqId,
			'' AS ExtraInfo,
			0 AS OriginalStake,
			0 AS OriginalBetType
		FROM
			dbo.bettrans AS b WITH (NOLOCK)
			INNER JOIN dbo.outright AS m WITH (NOLOCK) ON b.matchid = m.orid
			INNER JOIN dbo.league AS l WITH (NOLOCK) ON m.leagueID = l.leagueID 
			INNER JOIN @SportBettype AS sbt ON b.bettype = sbt.Bettype
		WHERE b.custid = @CustID
			AND b.recommend = @Recommend 
			AND b.matchid > 0
			AND sbt.ProductID = 1
			AND sbt.EventType = 2
			AND b.transid NOT IN ( SELECT TransId FROM #TempBATicket )
			AND b.transdate >= @FromDate AND b.transdate <= @ToDate

		-- Mix Parlay & System Parlay
		INSERT INTO #BetListSelAllByDateMem
		SELECT
			@UserName,
			0 AS sporttype,
			b.bettype,
			CONVERT(NVARCHAR(20),b.refno) AS refno,
			CASE
				WHEN (ISNULL(b.BetID,0) = 0 OR b.bettype = 9) THEN b.transid
				ELSE betid
			END AS transid,
			ISNULL(b.BetID,0),
			'' AS matchcode,
			b.matchid,
			'' AS Race,
			0 AS homeID,
			0 AS awayID,
			CONVERT(FLOAT, b.hdp1) AS hdp1,
			CONVERT(FLOAT, b.hdp2) AS hdp2,
			b.odds,
			b.modds,
			b.status,
			b.stake,
			b.actual_stake,
			(winlost-actual_stake) AS WinLost,
			- (b.winlost-b.actual_stake) AS LicenseeWL,
			b.comm,
			b.playercomm,
			b.discount,
			b.transdate,
			b.winlostdate,
			b.betteam,
			0 AS leagueID,
			b.liveindicator,
			b.livehomescore,
			b.liveawayscore,
			b.IP,
			'' AS betstatus,
			CONVERT(BIT,0) AS IsNeutral,
			0 AS OddsType,
			b.currency,
			'' AS ShowTime,
			ISNULL(b.betcheck, '') AS BetCheck,
			'' AS transdesc,
			-1 AS BetdaqId,
			'' AS ExtraInfo,
			0 AS OriginalStake,
			0 AS OriginalBetType
		FROM 
			dbo.bettrans AS b WITH (NOLOCK)
			INNER JOIN @SportBettype AS sbt ON b.bettype = sbt.Bettype
		WHERE b.CustID = @CustID
			AND b.recommend = @Recommend
			AND sbt.ProductID = 1
			AND sbt.EventType = 0
			AND b.matchid IN (9, 29) 
			AND b.transid NOT IN ( SELECT TransId FROM #TempBATicket )
			AND b.transdate >= @FromDate AND b.transdate <= @ToDate
	END

	-- Bet Trade
	IF @ShowBT = 1
	BEGIN
		INSERT INTO #BetListSelAllByDateMem
		SELECT
			@UserName,
			m.sporttype,
			b.bettype,
			b.refno,
			b.transid,
			ISNULL(ob.bettype, 0),
			m.matchcode,
			m.matchid,
			'' AS Race,
			m.homeid,
			m.awayid,
			CONVERT(FLOAT, b.hdp1) AS hdp1,
			CONVERT(FLOAT, b.hdp2) AS hdp2,
			ob.odds,
			b.modds,
			CASE
				WHEN b.status = 'running' AND ISNULL(b.SecAcceptFlag, 0) = 1
					AND ISNULL(b.checktime, CURRENT_TIMESTAMP) > CURRENT_TIMESTAMP THEN 'waiting'
				ELSE b.status
			END AS status,
			ob.stake,
			b.actual_stake,
			(b.winlost - b.actual_stake) AS WinLost,
			- (b.winlost - b.actual_stake) AS LicenseeWL,
			CASE
				WHEN b.bettype = 903 THEN b.awinlost
				ELSE b.comm
			END AS comm,
			b.playercomm,
			b.discount,
			b.transdate,
			b.winlostdate,
			b.betteam,
			m.leagueid,
			b.liveindicator,
			ob.livehomescore,
			ob.liveawayscore,
			b.ip,
			m.betstatus,
			ISNULL(m.isNeutral, CONVERT(BIT,0)) AS IsNeutral,
			b.oddstype,
			b.currency,
			'' AS ShowTime,
			'' AS betcheck,
			'' AS transdesc,
			-1 AS BetdaqId,
			'' AS ExtraInfo,
			0 AS OriginalStake,
			0 AS OriginalBetType
		FROM 
			dbo.bettrans AS b WITH (NOLOCK)
			INNER JOIN dbo.bettrans AS ob WITH(NOLOCK) ON b.refno = ob.transid
			INNER JOIN dbo.match AS m WITH (NOLOCK) ON b.matchid = m.matchid
			INNER JOIN @SportBettype AS sbt ON b.bettype = sbt.Bettype
		WHERE b.custid = @CustID
			AND b.recommend = @Recommend
			AND b.matchid > 0
			AND sbt.ProductID = 1
			AND sbt.EventType = 1
			AND b.transdate >= @FromDate AND b.transdate <= @ToDate
			AND b.bettype IN (901, 902, 903)

		UPDATE betList
		SET betList.comm = CASE
								WHEN betList.Bettype = 902 THEN commBetList.comm
								ELSE betList.comm
							END
		FROM #BetListSelAllByDateMem AS betList
			INNER JOIN #BetListSelAllByDateMem AS commBetList ON betList.RefNo = commBetList.RefNo
		WHERE betList.Sporttype = 1
			AND betList.Bettype IN (901, 902)
			AND commBetList.Bettype = 903

		DELETE #BetListSelAllByDateMem
		WHERE Sporttype = 1 AND Bettype = 903
	END

	-- Cash Out
	IF @ShowCO = 1
	BEGIN
		INSERT INTO #BetListSelAllByDateMem
		SELECT
			@UserName,
			m.sporttype,
			b.bettype,
			b.refno,
			b.transid,
			ISNULL(b.bettype, 0),
			m.matchcode,
			m.matchid,
			'' AS Race,
			m.homeid,
			m.awayid,
			CONVERT(FLOAT, b.hdp1) AS hdp1,
			CONVERT(FLOAT, b.hdp2) AS hdp2,
			b.odds,
			b.modds,
			CASE
				WHEN b.status = 'running' AND ISNULL(b.SecAcceptFlag, 0) = 1
					AND ISNULL(b.checktime, CURRENT_TIMESTAMP) > CURRENT_TIMESTAMP THEN 'waiting'
				ELSE b.status
			END AS status,
			b.stake,
			b.actual_stake,
			(b.winlost - b.actual_stake) AS WinLost,
			- (b.winlost - b.actual_stake) AS LicenseeWL,
			CASE
				WHEN b.bettype = 903 THEN b.awinlost
				ELSE b.comm
			END AS comm,
			b.playercomm,
			b.discount,
			b.transdate,
			b.winlostdate,
			b.betteam,
			m.leagueid,
			b.liveindicator,
			b.livehomescore,
			b.liveawayscore,
			b.ip,
			m.betstatus,
			ISNULL(m.isNeutral, CONVERT(BIT,0)) AS IsNeutral,
			b.oddstype,
			b.currency,
			'' AS ShowTime,
			'' AS betcheck,
			'' AS transdesc,
			-1 AS BetdaqId,
			'' AS ExtraInfo,
			0 AS OriginalStake,
			0 AS OriginalBetType
		FROM
			dbo.bettrans AS b WITH (NOLOCK)
			INNER JOIN dbo.match AS m WITH (NOLOCK) ON b.matchid = m.matchid
			INNER JOIN @SportBettype AS sbt ON b.Bettype = sbt.Bettype
		WHERE
			b.transdate BETWEEN @FromDate AND @ToDate
			AND b.custid = @CustId
			AND sbt.ProductID = 25

		-- Get more info for CashOut tickets
		IF EXISTS (SELECT TOP 1 1 FROM #BetListSelAllByDateMem WHERE BetType = 911)
		BEGIN
			UPDATE b
			SET b.Odds = ob.odds,
				b.LiveHomeScore = ob.livehomescore,
				b.LiveAwayScore = ob.liveawayscore,
				b.OriginalBetType = ob.bettype,
				b.BetdaqId = ob.transid
			FROM #BetListSelAllByDateMem AS b
				INNER JOIN dbo.bettrans AS ob WITH (NOLOCK) ON b.RefNo = ob.transid
			WHERE b.BetType = 911
		END

		IF EXISTS (SELECT TOP 1 1 FROM #BetListSelAllByDateMem WHERE BetType = 912)
		BEGIN
			UPDATE b
			SET b.Odds = ob.odds,
				b.LiveHomeScore = ob.livehomescore,
				b.LiveAwayScore = ob.liveawayscore,
				b.OriginalBetType = ob.bettype,
				b.BetdaqId = ob.transid,
				b.Stake = cob.stake,
				b.Comm = ISNULL(cb.Comm, 0)
			FROM #BetListSelAllByDateMem AS b
				INNER JOIN dbo.bettrans AS cob WITH (NOLOCK) ON b.RefNo = cob.transid
				INNER JOIN dbo.bettrans AS ob WITH (NOLOCK) ON cob.RefNo = ob.transid
				LEFT JOIN #BetListSelAllByDateMem AS cb ON b.RefNo = cb.RefNo AND cb.BetType = 913
			WHERE b.BetType = 912
		END

		DELETE #BetListSelAllByDateMem WHERE Bettype = 913
	END

	DROP TABLE #TempBATicket;

	-- Horse Racing
	IF @ShowRB = 1
	BEGIN
		INSERT INTO #BetListSelAllByDateMem
		SELECT
			@UserName,
			151 AS sporttype,
			b.bettype,
			b.refno,
			b.transid,
			ISNULL(b.betid, 0),
			m.matchcode,
			b.matchid,
			m.GroupMatch AS Race,
			m.teamID AS homeID,
			0 AS awayID,
			CONVERT(FLOAT, b.hdp1) AS hdp1,
			CONVERT(FLOAT, b.hdp2) AS hdp2,
			b.odds,
			b.modds,
			CASE
				WHEN b.status = 'running' AND ISNULL(b.SecAcceptFlag, 0) = 1 
					AND ISNULL(b.checktime, CURRENT_TIMESTAMP) > CURRENT_TIMESTAMP THEN 'waiting'
				ELSE b.status
			END AS status,
			b.stake,
			b.actual_stake,
			(winlost-actual_stake) AS winlost,
			b.awinlost,
			b.comm,
			b.playercomm,
			b.discount,
			b.transdate,
			b.winlostdate,
			'' AS Betteam,
			m.leagueID,
			0 AS liveindicator,
			b.livehomescore,
			b.liveawayscore,
			b.ip,
			'' AS betstatus,
			CONVERT(BIT,0) AS IsNeutral,
			0 AS oddstype,
			b.currency,
			'' AS ShowTime,
			'' AS betcheck,
			'' AS transdesc,
			-1 AS BetdaqId,
			'' AS ExtraInfo,
			0 AS OriginalStake,
			0 AS OriginalBetType
		FROM
			dbo.bettrans AS b WITH (NOLOCK)
			INNER JOIN dbo.outright AS m WITH (NOLOCK) ON b.matchid = m.orid
			INNER JOIN @SportBettype AS sbt ON b.bettype = sbt.Bettype
		WHERE b.custid = @CustID
			AND b.recommend = @Recommend
			AND b.matchid > 0
			AND sbt.ProductID = 2
			AND sbt.EventType = 2
			AND b.transdate >= @FromDate AND b.transdate <= @ToDate
	END

	-- Number Game, Live Casino, Virtual Sports
	IF @ShowNG = 1 OR @ShowLC = 1 OR @ShowVS = 1
	BEGIN
		INSERT INTO #BetListSelAllByDateMem
		SELECT
			@UserName,
			m.sporttype,
			b.bettype,
			b.refno,
			b.transid,
			ISNULL(b.BetID,0),
			m.matchcode,
			m.matchid,
			'' AS Race,
			m.homeid,
			m.awayID,
			CONVERT(FLOAT, b.hdp1) AS hdp1,
			CONVERT(FLOAT, b.hdp2) AS hdp2,
			b.odds,
			b.modds,
			CASE
				WHEN b.status = 'running' AND ISNULL(b.SecAcceptFlag, 0) = 1 
					AND ISNULL(b.checktime, CURRENT_TIMESTAMP) > CURRENT_TIMESTAMP THEN 'waiting'
				ELSE b.status
			END AS status,
			b.stake,
			b.actual_stake,
			(winlost-actual_stake) AS winlost,
			- (b.winlost-b.actual_stake) AS LicenseeWL,
			b.comm,
			b.playercomm,
			b.discount,
			b.transdate,
			b.winlostdate,
			b.betteam,
			m.leagueid,
			b.liveindicator,
			b.livehomescore,
			b.liveawayscore,
			b.ip,
			m.betstatus,
			CONVERT(BIT,0) AS IsNeutral,
			b.Oddstype,
			b.currency,
			CASE
				WHEN b.bettype BETWEEN 1101 AND 1199 THEN ISNULL(m.showtime, '')
				WHEN sbt.ProductID = 5 THEN CONVERT(NVARCHAR(50), m.kickofftime)
				ELSE ''
			END AS ShowTime,
			'' AS betcheck,
			'' AS transdesc,
			-1 AS BetdaqId,
			'' AS ExtraInfo,
			0 AS OriginalStake,
			0 AS OriginalBetType
		FROM 
			dbo.bettrans AS b WITH (NOLOCK)
			INNER JOIN dbo.match AS m WITH (NOLOCK) ON b.matchid = m.matchid
			INNER JOIN @SportBettype AS sbt ON b.bettype = sbt.Bettype
		WHERE
			b.custid = @CustID
			AND b.recommend = @Recommend
			AND sbt.ProductID IN (3, 4, 5)
			AND sbt.EventType = 1
			AND b.transdate >= @FromDate AND b.transdate <= @ToDate

		UNION
		SELECT
			@UserName,
			r.sporttype,
			b.bettype,
			CONVERT(NVARCHAR(20), b.refno) AS refno,
			b.transid,
			ISNULL(b.betid, 0),
			CONVERT(VARCHAR(50), o.RacerNum) AS matchcode,
			o.EventID AS matchid,
			b.oddsid AS Race,
			o.RacerID AS homeID,
			0 AS awayID,
			CONVERT(FLOAT, b.hdp1) AS hdp1,
			CONVERT(FLOAT, b.hdp2) AS hdp2,
			b.odds,
			b.modds,
			CASE
				WHEN b.status = 'running' AND ISNULL(b.SecAcceptFlag, 0) = 1
					AND ISNULL(b.checktime, CURRENT_TIMESTAMP) > CURRENT_TIMESTAMP THEN 'waiting'
				ELSE b.status
			END AS status,
			b.stake,
			b.actual_stake,
			(winlost-actual_stake) AS WinLost,
			- (b.winlost-b.actual_stake) AS LicenseeWL,
			b.comm,
			b.playercomm,
			b.discount,
			b.transdate,
			b.winlostdate,
			b.betteam,
			r.leagueID,
			b.liveindicator,
			b.livehomescore,
			b.liveawayscore,
			b.ip,
			r.betstatus,
			CONVERT(BIT,0) AS IsNeutral,
			b.Oddstype,
			b.currency,
			CONVERT(VARCHAR(20),r.EventTime) AS ShowTime,
			'' AS betcheck,
			'' AS transdesc,
			-1 AS BetdaqId,
			'' AS ExtraInfo,
			0 AS OriginalStake,
			0 AS OriginalBetType
		FROM dbo.bettrans AS b WITH (NOLOCK)
			INNER JOIN dbo.VSOutright AS o WITH (NOLOCK) ON b.oddsid = o.Orid
			INNER JOIN dbo.VSRaceInfo AS r WITH (NOLOCK) ON r.EventID = o.EventID
			INNER JOIN @SportBettype AS sbt ON b.bettype = sbt.Bettype
		WHERE
			b.CustID = @CustID
			AND b.recommend = @Recommend
			AND sbt.ProductID = 5
			AND sbt.EventType = 3
			AND b.transdate >= @FromDate AND b.transdate <= @ToDate
	END

	-- RNG Casino
	IF @ShowCS = 1
	BEGIN
		INSERT INTO #BetListSelAllByDateMem
		SELECT 
			@UserName AS UserName,
			251 AS SportType,
			b.bettype,
			b.refno,
			b.transid,
			ISNULL(b.betid, 0),
			'' AS matchcode,
			71 AS matchid,
			'' AS Race,
			0 AS homeID,
			0 AS awayID,
			CONVERT(FLOAT, b.hdp1) AS hdp1,
			CONVERT(FLOAT, b.hdp2) AS hdp2,
			b.odds,
			b.modds,
			CASE
				WHEN b.status = 'running' AND ISNULL(b.SecAcceptFlag, 0) = 1 
					AND ISNULL(b.checktime, CURRENT_TIMESTAMP) > CURRENT_TIMESTAMP THEN 'waiting'
				ELSE b.status
			END AS status,
			b.stake,
			b.actual_stake,
			(winlost-actual_stake) AS WinLost,
			- (b.winlost-b.actual_stake) AS LicenseeWL,
			b.comm,
			b.playercomm,
			b.discount,
			b.transdate,
			b.winlostdate,
			b.betteam,
			0 AS leagueID,
			b.liveindicator,
			b.livehomescore,
			b.liveawayscore,
			b.IP,
			0 AS betstatus,
			CONVERT(BIT,0) AS IsNeutral,
			b.Oddstype,
			b.currency,
			'' AS ShowTime,
			'' AS betcheck,
			'' AS transdesc,
			-1 AS BetdaqId,
			'' AS ExtraInfo,
			0 AS OriginalStake,
			0 AS OriginalBetType
		FROM 
			dbo.bettrans AS b WITH (NOLOCK)
			INNER JOIN @SportBettype AS sbt ON b.bettype = sbt.Bettype
		WHERE
			b.custid = @CustID
			AND b.recommend = @Recommend
			AND sbt.ProductID = 6 AND sbt.SubProduct = ''
			AND sbt.EventType = 0
			AND b.transdate >= @FromDate AND b.transdate <= @ToDate
	END

	-- Keno
	IF @ShowKN = 1
	BEGIN
		INSERT INTO #BetListSelAllByDateMem
		SELECT
			@UserName,
			202 AS sporttype,
			b.bettype,
			b.refno,
			b.transid,
			ISNULL(b.betid, 0),
			'' AS matchcode,
			t.GameId AS matchid,
			'' AS Race,
			0 AS homeID,
			0 AS awayID,
			0 AS hdp1,
			0 AS hdp2,
			b.odds,
			b.modds,
			b.status,
			b.stake,
			b.actual_stake,
			(winlost-actual_stake) AS WinLost,
			- (b.winlost-b.actual_stake) AS LicenseeWL,
			b.comm,
			b.playercomm,
			b.discount,
			b.transdate,
			b.winlostdate,
			t.ChoiceId AS betteam,
			0 AS leagueID,
			0 AS liveindicator,
			0 AS livehomescore,
			0 AS liveawayscore,
			b.ip,
			0 AS betstatus,
			CONVERT(BIT,0) AS IsNeutral,
			b.Oddstype,
			b.currency,
			'' AS ShowTime,
			'' AS betcheck,
			'' AS transdesc,
			-1 AS BetdaqId,
			'' AS ExtraInfo,
			0 AS OriginalStake,
			0 AS OriginalBetType
		FROM 
			dbo.bettrans AS b WITH (NOLOCK)
			INNER JOIN @SportBettype AS sbt ON b.bettype = sbt.Bettype
			CROSS APPLY dbo.[f_ParseTransDesc](b.TransDesc, b.bettype) t
		WHERE
			b.CustID = @CustID
			AND b.recommend = @Recommend
			AND sbt.ProductID = 8
			AND sbt.EventType = 0
			AND b.transdate >= @FromDate AND b.transdate <= @ToDate 
			AND b.statusID NOT IN (0, 1)

		UNION ALL
		SELECT
			@UserName,
			202 AS sporttype,
			t.gameid AS bettype,
			t.translogid AS refno,
			t.translogid AS transid,
			0 AS BetID,
			'' AS matchcode,
			k.GameId AS matchid,
			'' AS Race,
			0 AS homeID,
			0 AS awayID,
			0 AS hdp1,
			0 AS hdp2,
			t.odds,
			0 AS modds,
			t.status,
			t.stake,
			t.actual_stake,
			(0-actual_stake) AS WinLost,
			- (0-t.actual_stake) AS LicenseeWL,
			0 AS comm,
			0 AS PlayerComm,
			t.discount,
			t.transdate,
			t.winlostdate,
			k.ChoiceId AS betteam,
			0 AS leagueID,
			0 AS liveindicator,
			0 AS livehomescore,
			0 AS liveawayscore,
			t.ip,
			0 AS betstatus,
			CONVERT(BIT,0) AS IsNeutral,
			0 AS Oddstype,
			t.currency,
			'' AS ShowTime,
			'' AS betcheck,
			'' AS transdesc,
			-1 AS BetdaqId,
			'' AS ExtraInfo,
			0 AS OriginalStake,
			0 AS OriginalBetType
		FROM 
			dbo.translog AS t WITH (NOLOCK)
			INNER JOIN @SportBettype sbt ON t.gameID = sbt.Bettype
			CROSS APPLY dbo.[f_ParseTransDesc](t.TransDesc, t.gameid) k
		WHERE
			t.CustID = @CustID
			AND t.recommend = @Recommend 
			AND sbt.ProductID = 8
			AND sbt.EventType = 0
			AND t.transdate >= @FromDate AND t.transdate <= @ToDate
			AND t.statusID IN (0, 1)
	END

	-- Microgaming Live Casino, Colossus Bets (translog)
	IF @ShowMGCLC = 1 OR @ShowCB = 1
	BEGIN
		INSERT INTO #BetListSelAllByDateMem
		SELECT
			@UserName AS UserName,
			CASE
				WHEN sbt.ProductID = 13 THEN 203
				WHEN sbt.ProductID = 15 THEN 204
				ELSE 0
			END AS SportType,
			t.gameid AS BetType,
			t.translogid AS RefNo,
			t.translogid AS TransId,
			0 AS BetId,
			'' AS MatchCode,
			0 AS MatchId,
			'' AS Race,
			0 AS HomeId,
			0 AS AwayId,
			0 AS hdp1,
			0 AS hdp2,
			0 AS Odds,
			0 AS MOdds,
			t.status,
			t.stake,
			t.actual_stake,
			0 AS WinLost,
			0 AS LicenseeWL,
			0 AS Comm,
			0 AS PlayerComm,
			t.discount,
			t.transdate,
			t.winlostdate,
			'' AS BetTeam,
			0 AS LeagueId,
			0 AS LiveIndicator,
			0 AS LiveHomeScore,
			0 AS LiveAwayScore,
			t.ip,
			0 AS BetStatus,
			CONVERT(BIT, 0) AS IsNeutral,
			0 AS OddsType,
			t.currency,
			'' AS ShowTime,
			CASE
				WHEN sbt.ProductID = 15 THEN t.Tranid3rd
				ELSE '' 
			END AS BetCheck,
			'' AS transdesc,
			-1 AS BetdaqId,
			'' AS ExtraInfo,
			0 AS OriginalStake,
			0 AS OriginalBetType
		FROM 
			dbo.translog AS t WITH (NOLOCK)
			INNER JOIN @SportBettype AS sbt ON t.gameID = sbt.Bettype
		WHERE
			t.custid = @CustID
			AND t.recommend = @Recommend
			AND sbt.ProductID IN (13, 15)
			AND sbt.EventType = 0
			AND t.transdate BETWEEN @FromDate AND @ToDate 
			AND t.statusID IN (0, 1)
	END

	-- Microgaming Live Casino (bettrans)
	IF @ShowMGCLC = 1
	BEGIN
		INSERT INTO #BetListSelAllByDateMem
		SELECT
			@UserName,
			203 AS sporttype,
			b.bettype,
			b.refno,
			b.transid,
			ISNULL(b.betid, 0),
			'' AS matchcode,
			0 AS matchid,
			'' AS Race,
			0 AS homeID,
			0 AS awayID,
			0 AS hdp1,
			0 AS hdp2,
			0 AS odds,
			0 AS modds,
			b.status,
			b.stake,
			b.actual_stake,
			(winlost - actual_stake) AS WinLost,
			- (b.winlost - b.actual_stake) AS LicenseeWL,
			b.comm,
			b.playercomm,
			b.discount,
			b.transdate,
			b.winlostdate,
			'' AS betteam,
			0 AS leagueID,
			0 AS liveindicator,
			0 AS livehomescore,
			0 AS liveawayscore,
			b.ip,
			0 AS betstatus,
			CONVERT(BIT, 0) AS IsNeutral,
			0 AS Oddstype,
			b.currency,
			'' AS ShowTime,
			b.betcheck,
			'' AS transdesc,
			-1 AS BetdaqId,
			'' AS ExtraInfo,
			0 AS OriginalStake,
			0 AS OriginalBetType
		FROM 
			dbo.bettrans AS b WITH (NOLOCK)
			INNER JOIN @SportBettype AS sbt ON b.bettype = sbt.Bettype
		WHERE
			b.custid = @CustID
			AND b.recommend = @Recommend
			AND sbt.ProductID = 13
			AND sbt.EventType = 0
			AND b.transdate BETWEEN @FromDate AND @ToDate 
			AND b.statusID NOT IN (0, 1)
	END

	-- Colossus Bets (bettrans)
	IF @ShowCB = 1
	BEGIN
		INSERT INTO #BetListSelAllByDateMem
		SELECT
			@UserName,
			204 AS SportType,
			b.bettype,
			b.refno,
			b.transid,
			ISNULL(b.betid, 0),
			'' AS MatchCode,
			0 AS MatchId,
			'' AS Race,
			0 AS HomeId,
			0 AS AwayId,
			0 AS hdp1,
			0 AS hdp2,
			0 AS Odds,
			0 AS MOdds,
			b.status,
			b.stake,
			b.actual_stake,
			(b.winlost - b.actual_stake) AS WinLost,
			0 AS LicenseeWL,
			b.comm,
			b.playercomm,
			b.discount,
			b.transdate,
			b.winlostdate,
			'' AS BetTeam,
			0 AS LeagueId,
			0 AS LiveIndicator,
			0 AS LiveHomeScore,
			0 AS LiveAwayScore,
			b.ip,
			0 AS betstatus,
			CONVERT(BIT, 0) AS IsNeutral,
			0 AS Oddstype,
			b.currency,
			'' AS ShowTime,
			ISNULL(bm.betcheck, '') AS BetCheck,
			'' AS transdesc,
			-1 AS BetdaqId,
			'' AS ExtraInfo,
			0 AS OriginalStake,
			0 AS OriginalBetType
		FROM
			dbo.bettrans AS b WITH (NOLOCK)
			INNER JOIN @SportBettype sbt ON b.bettype = sbt.Bettype
			LEFT JOIN dbo.bettransm AS bm WITH (NOLOCK) ON b.refno = bm.refno AND bm.bettype = 18001
		WHERE
			b.custid = @custid
			AND b.recommend = @Recommend
			AND b.transdate BETWEEN @FromDate AND @ToDate 
			AND sbt.ProductID = 15
	END

	-- Microgaming RNG Casino, RNG Casino Single Wallet, Macau Games, Fishing World
	IF @ShowCS = 1 OR @ShowMGCRNG = 1 OR @ShowVB = 1 OR @ShowFW = 1
	BEGIN
		-- Up to yesterday settled ticket
		INSERT INTO #BetListSelAllByDateMem
		SELECT
			@UserName,
			CASE
				WHEN sbt.ProductID = 6 THEN b.matchid
				WHEN sbt.ProductID = 17 THEN 205
				WHEN sbt.ProductID = 22 THEN 212
				WHEN sbt.ProductID = 24 THEN 219
			END AS Sporttype,
			b.bettype,
			b.refno,
			b.transid,
			ISNULL(b.betid, 0),
			'' AS matchcode,
			0 AS matchid,
			'' AS Race,
			0 AS homeID,
			0 AS awayID,
			0 AS hdp1,
			0 AS hdp2,
			0 AS odds,
			0 AS modds,
			b.status,
			b.stake,
			b.actual_stake,
			(winlost - actual_stake) AS winlost,
			- (b.winlost - b.actual_stake) AS LicenseeWL,
			b.comm,
			b.playercomm,
			b.discount,
			b.transdate,
			b.winlostdate,
			'' AS betteam,
			0 AS leagueID,
			0 AS liveindicator,
			0 AS livehomescore,
			0 AS liveawayscore,
			b.ip,
			0 AS betstatus,
			CONVERT(BIT, 0) AS IsNeutral,
			0 AS Oddstype,
			b.currency,
			'' AS ShowTime,
			'' AS betcheck,
			CASE
				WHEN sbt.ProductID IN (6, 22, 24) THEN b.transdesc
				ELSE ''
			END AS transdesc,
			-1 AS BetdaqId,
			'' AS ExtraInfo,
			0 AS OriginalStake,
			0 AS OriginalBetType
		FROM 
			dbo.bettrans AS b WITH (NOLOCK)
			INNER JOIN @SportBettype AS sbt ON b.bettype = sbt.Bettype
		WHERE
			b.custid = @CustID
			AND b.recommend = @Recommend
			AND (sbt.ProductID IN (17, 22, 24)
				OR (sbt.ProductID = 6 AND sbt.SubProduct <> ''))
			AND sbt.EventType = 0
			AND b.transdate >= @FromDate AND b.transdate <= @ToDate 
			AND b.winlostdate < @Yesterday	-- not yesterday and today summary ticket
			AND b.statusID NOT IN (0, 1)

		-- Yesterday and today running ticket
		INSERT INTO #BetListSelAllByDateMem
		SELECT
			@UserName,
			CASE
				WHEN sbt.ProductID = 6 THEN b.matchid
				WHEN sbt.ProductID = 17 THEN 205
				WHEN sbt.ProductID = 22 THEN 212
				WHEN sbt.ProductID = 24 THEN 219
			END AS Sporttype,
			b.bettype,
			b.refno,
			b.transid,
			ISNULL(b.BetID, 0),
			'' AS matchcode,
			0 AS matchid,
			'' AS Race,
			0 AS homeID,
			0 AS awayID,
			0 AS hdp1,
			0 AS hdp2,
			0 AS odds,
			0 AS modds,
			'Running' AS Status,
			SUM(brng.stake) AS Stake,
			SUM(brng.actual_stake) AS Actual_Stake,
			0 AS Winlost,
			0 AS LicenseeWL,
			0 AS comm,
			0 AS playercomm,
			0 AS discount,
			b.transdate,
			b.winlostdate,
			'' AS betteam,
			0 AS leagueID,
			0 AS liveindicator,
			0 AS livehomescore,
			0 AS liveawayscore,
			b.ip,
			0 AS betstatus,
			CONVERT(BIT, 0) AS IsNeutral,
			0 AS Oddstype,
			b.currency,
			'' AS ShowTime,
			'' AS betcheck,
			CASE
				WHEN sbt.ProductID IN (6, 22, 24) THEN b.transdesc
				ELSE ''
			END AS transdesc,
			-1 AS BetdaqId,
			'' AS ExtraInfo,
			0 AS OriginalStake,
			0 AS OriginalBetType
		FROM 
			dbo.bettransRnG AS brng WITH (NOLOCK)
			INNER JOIN dbo.bettrans AS b WITH (NOLOCK) ON brng.RefNo = b.transid
			INNER JOIN @SportBettype AS sbt ON b.bettype = sbt.Bettype
		WHERE
			b.custid = @CustID
			AND b.recommend = @Recommend
			AND (sbt.ProductID IN (17, 22, 24)
				OR (sbt.ProductID = 6 AND sbt.SubProduct <> ''))
			AND sbt.EventType = 0
			AND b.transdate >= @FromDate AND b.transdate <= @ToDate 
			AND b.winlostdate BETWEEN @Yesterday AND @Today
			AND brng.statusID = 0
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

		-- Today settled ticket
		INSERT INTO #BetListSelAllByDateMem
		SELECT 
			@UserName AS UserName,
			CASE
				WHEN sbt.ProductID = 6 THEN b.matchid
				WHEN sbt.ProductID = 17 THEN 205
				WHEN sbt.ProductID = 22 THEN 212
				WHEN sbt.ProductID = 24 THEN 219
			END AS Sporttype,
			b.bettype,
			b.refno,
			b.transid,
			ISNULL(b.BetID, 0),
			'' AS matchcode,
			0 AS matchid,
			'' AS Race,
			0 AS homeID,
			0 AS awayID,
			0 AS hdp1,
			0 AS hdp2,
			0 AS odds,
			0 AS modds,
			CASE 
				WHEN SUM(brng.winlost - brng.actual_stake) = 0 THEN 'Draw'
				WHEN SUM(brng.winlost - brng.actual_stake) > 0 THEN 'Won'
				WHEN SUM(brng.winlost - brng.actual_stake) < 0 THEN 'Lose'
			END AS Status,
			SUM(brng.stake) AS Stake,
			SUM(brng.actual_stake) AS Actual_Stake,
			SUM(brng.winlost - brng.actual_stake) AS Winlost,
			SUM(- (brng.winlost - brng.actual_stake)) AS LicenseeWL,
			SUM(brng.comm) AS comm,
			SUM(brng.playercomm) AS playercomm,
			b.discount,
			b.transdate,
			b.winlostdate,
			'' AS betteam,
			0 AS leagueID,
			0 AS liveindicator,
			0 AS livehomescore,
			0 AS liveawayscore,
			b.ip,
			0 AS betstatus,
			CONVERT(BIT, 0) AS IsNeutral,
			0 AS Oddstype,
			b.currency,
			'' AS ShowTime,
			'' AS betcheck,
			CASE
				WHEN sbt.ProductID IN (6, 22, 24) THEN b.transdesc
				ELSE ''
			END AS transdesc,
			-1 AS BetdaqId,
			'' AS ExtraInfo,
			0 AS OriginalStake,
			0 AS OriginalBetType
		FROM 
			dbo.bettransRnG AS brng WITH (NOLOCK)
			INNER JOIN dbo.bettrans AS b WITH (NOLOCK) ON brng.RefNo = b.transid
			INNER JOIN @SportBettype AS sbt ON b.bettype = sbt.Bettype
		WHERE
			b.custid = @CustID
			AND b.recommend = @Recommend
			AND (sbt.ProductID IN (17, 22, 24)
				OR (sbt.ProductID = 6 AND sbt.SubProduct <> ''))
			AND sbt.EventType = 0
			AND b.transdate >= @FromDate AND b.transdate <= @ToDate 
			AND b.winlostdate BETWEEN @Yesterday AND @Today
			AND brng.statusID <> 0
		GROUP BY
			b.transid,
			ISNULL(b.betid, 0),
			b.bettype,
			b.refno,
			b.discount,
			b.transdate,
			b.winlostdate,
			b.ip,
			b.currency,
			b.matchid,
			b.transdesc,
			sbt.ProductID
	END

	-- AG Casino, AllBet
	IF @ShowAGC = 1 OR @ShowAB = 1
	BEGIN
		-- Up to yesterday settled ticket
		INSERT INTO #BetListSelAllByDateMem
		SELECT 
			@UserName AS UserName,
			CASE
				WHEN sbt.ProductID = 11 THEN 250
				WHEN sbt.ProductID = 21 THEN 211
			END AS Sporttype,
			b.bettype,
			b.refno,
			b.transid,
			ISNULL(b.BetID, 0),
			'' AS matchcode,
			0 AS matchid,
			'' AS Race,
			0 AS homeID,
			0 AS awayID,
			0 AS hdp1,
			0 AS hdp2,
			0 AS odds,
			0 AS modds,
			b.status,
			b.stake,
			b.actual_stake,
			(winlost - actual_stake) AS winlost,
			- (b.winlost - b.actual_stake) AS LicenseeWL,
			b.comm,
			b.playercomm,
			b.discount,
			b.transdate,
			b.winlostdate,
			'' AS betteam,
			0 AS leagueID,
			0 AS liveindicator,
			0 AS livehomescore,
			0 AS liveawayscore,
			b.ip,
			0 AS betstatus,
			CONVERT(BIT, 0) AS IsNeutral,
			0 AS Oddstype,
			b.currency,
			'' AS ShowTime,
			'' AS betcheck,
			'' AS transdesc,
			-1 AS BetdaqId,
			'' AS ExtraInfo,
			0 AS OriginalStake,
			0 AS OriginalBetType
		FROM 
			dbo.bettrans AS b WITH (NOLOCK)
			INNER JOIN @SportBettype AS sbt ON b.bettype = sbt.Bettype
		WHERE
			b.custid = @CustID
			AND b.recommend = @Recommend
			AND sbt.ProductID IN (11, 21)
			AND sbt.EventType = 0
			AND b.transdate >= @FromDate AND b.transdate <= @ToDate 
			AND b.winlostdate < @Yesterday	-- not yesterday and today summary ticket
			AND b.statusID NOT IN (0, 1)

		-- Yesterday and today running ticket
		INSERT INTO #BetListSelAllByDateMem
		SELECT
			@UserName AS UserName,
			CASE
				WHEN sbt.ProductID = 11 THEN 250
				WHEN sbt.ProductID = 21 THEN 211
			END AS Sporttype,
			b.bettype,
			b.refno,
			b.transid,
			ISNULL(b.BetID, 0),
			'' AS matchcode,
			0 AS matchid,
			'' AS Race,
			0 AS homeID,
			0 AS awayID,
			0 AS hdp1,
			0 AS hdp2,
			0 AS odds,
			0 AS modds,
			'Running' AS Status,
			SUM(blc.stake) AS Stake,
			SUM(blc.actual_stake) AS Actual_Stake,
			0 AS Winlost,
			0 AS LicenseeWL,
			0 AS comm,
			0 AS playercomm,
			0 AS discount,
			b.transdate,
			b.winlostdate,
			'' AS betteam,
			0 AS leagueID,
			0 AS liveindicator,
			0 AS livehomescore,
			0 AS liveawayscore,
			b.ip,
			0 AS betstatus,
			CONVERT(BIT, 0) AS IsNeutral,
			0 AS Oddstype,
			b.currency,
			'' AS ShowTime,
			'' AS betcheck,
			'' AS transdesc,
			-1 AS BetdaqId,
			'' AS ExtraInfo,
			0 AS OriginalStake,
			0 AS OriginalBetType
		FROM 
			dbo.bettransLC AS blc WITH (NOLOCK)
			INNER JOIN dbo.bettrans AS b WITH (NOLOCK) ON blc.RefNo = b.transid
			INNER JOIN @SportBettype AS sbt ON b.bettype = sbt.Bettype
		WHERE
			b.custid = @CustID
			AND b.recommend = @Recommend
			AND sbt.ProductID IN (11, 21)
			AND sbt.EventType = 0
			AND b.transdate >= @FromDate AND b.transdate <= @ToDate 
			AND b.winlostdate BETWEEN @Yesterday AND @Today		-- yesterday and today
			AND blc.statusID = 0
		GROUP BY
			b.transid,
			ISNULL(b.betid, 0),
			b.bettype,
			b.refno,
			b.transdate,
			b.winlostdate,
			b.ip,
			b.currency,
			sbt.ProductID

		-- Yesterday and today settled ticket
		INSERT INTO #BetListSelAllByDateMem
		SELECT 
			@UserName AS UserName,
			CASE
				WHEN sbt.ProductID = 11 THEN 250
				WHEN sbt.ProductID = 21 THEN 211
			END AS Sporttype,
			b.bettype,
			b.refno,
			b.transid,
			ISNULL(b.BetID, 0),
			'' AS matchcode,
			0 AS matchid,
			'' AS Race,
			0 AS homeID,
			0 AS awayID,
			0 AS hdp1,
			0 AS hdp2,
			0 AS odds,
			0 AS modds,
			CASE 
				WHEN SUM(blc.winlost - blc.actual_stake) = 0 THEN 'Draw'
				WHEN SUM(blc.winlost - blc.actual_stake) > 0 THEN 'Won'
				WHEN SUM(blc.winlost - blc.actual_stake) < 0 THEN 'Lose'
			END AS Status,
			SUM(blc.stake) AS Stake,
			SUM(blc.actual_stake) AS Actual_Stake,
			SUM(blc.winlost - blc.actual_stake) AS Winlost,
			SUM(- (blc.winlost - blc.actual_stake)) AS LicenseeWL,
			SUM(blc.comm) AS comm,
			SUM(blc.playercomm) AS playercomm,
			b.discount,
			b.transdate,
			b.winlostdate,
			'' AS betteam,
			0 AS leagueID,
			0 AS liveindicator,
			0 AS livehomescore,
			0 AS liveawayscore,
			b.ip,
			0 AS betstatus,
			CONVERT(BIT, 0) AS IsNeutral,
			0 AS Oddstype,
			b.currency,
			'' AS ShowTime,
			'' AS betcheck,
			'' AS transdesc,
			-1 AS BetdaqId,
			'' AS ExtraInfo,
			0 AS OriginalStake,
			0 AS OriginalBetType
		FROM 
			dbo.bettransLC AS blc WITH (NOLOCK)
			INNER JOIN dbo.bettrans AS b WITH (NOLOCK) ON blc.RefNo = b.transid
			INNER JOIN @SportBettype AS sbt ON b.bettype = sbt.Bettype
		WHERE
			b.custid = @CustID
			AND b.recommend = @Recommend
			AND sbt.ProductID IN (11, 21)
			AND sbt.EventType = 0
			AND b.transdate >= @FromDate AND b.transdate <= @ToDate 
			AND b.winlostdate BETWEEN @Yesterday AND @Today		-- yesterday and today
			AND blc.statusID <> 0
		GROUP BY
			b.transid,
			ISNULL(b.betid, 0),
			b.bettype,
			b.refno,
			b.discount,
			b.transdate,
			b.winlostdate,
			b.ip,
			b.currency,
			sbt.ProductID
	END

	CREATE NONCLUSTERED INDEX IDX_Index_betlist ON #BetListSelAllByDateMem(Currency)

	DECLARE @WinLostDate DATETIME,
		@ExchangeToDate DATETIME

	-- Get exchange rate due to winlostdate
	SELECT @WinLostDate = MAX(WinLostDate)
	FROM #BetListSelAllByDateMem

	SELECT @ExchangeToDate = CASE
								WHEN @WinLostDate IS NULL OR @WinLostDate <= @ToDate THEN @ToDate
								ELSE @WinLostDate
							END

	SELECT *
	INTO #TempExchange
	FROM Lrf_f_GetExchangeDaily(@FromDate, @ExchangeToDate) ex
	WHERE ex.ExchangeId IN (SELECT DISTINCT Currency FROM #BetListSelAllByDateMem)

	SELECT
		@TotalRows			= COUNT(1),
		@SumWinlost			= SUM(ISNULL(b.WinLost, 0)),
		@SumWinlostUSD		= SUM(ISNULL(b.WinLost * e.USD, 0)),
		@SumWinlostEUR		= SUM(ISNULL(b.WinLost * e.EUR, 0)),
		@SumWinlostGBP		= SUM(ISNULL(b.WinLost * e.GBP, 0)),
		@SumLicenseeWL		= SUM(ISNULL(b.LicenseeWL, 0)),
		@SumLicenseeWLUSD	= SUM(ISNULL(b.LicenseeWL * e.USD, 0)),
		@SumLicenseeWLEUR	= SUM(ISNULL(b.LicenseeWL * e.EUR, 0)),
		@SumLicenseeWLGBP	= SUM(ISNULL(b.LicenseeWL * e.GBP, 0)),
		@SumComm			= SUM(ISNULL(b.Comm, 0)),
		@SumCommUSD			= SUM(ISNULL(b.Comm * e.USD, 0)),
		@SumCommEUR			= SUM(ISNULL(b.Comm * e.EUR, 0)),
		@SumCommGBP			= SUM(ISNULL(b.Comm * e.GBP, 0)),
		@SumPlayerComm		= SUM(ISNULL(b.PlayerComm, 0)),
		@SumPlayerCommUSD	= SUM(ISNULL(b.PlayerComm * e.USD, 0)),
		@SumPlayerCommEUR	= SUM(ISNULL(b.PlayerComm * e.EUR, 0)),
		@SumPlayerCommGBP	= SUM(ISNULL(b.PlayerComm * e.GBP, 0))
	FROM #BetListSelAllByDateMem AS b
		INNER JOIN #TempExchange AS e
			ON e.ExchangeDate = (CASE WHEN b.winlostdate > @Today THEN @Today ELSE b.winlostdate END) 
				AND e.exchangeid = b.currency
	WHERE b.[status] <> 'running'

	-- return betlist single ticket
	SELECT T.*
	FROM (
		SELECT
			ROW_NUMBER() OVER(ORDER BY b.transid DESC) AS RowNum,
			b.*,
			-- USD
			b.Stake			* e.USD AS StakeUSD,
			b.Actual_Stake	* e.USD AS Actual_StakeUSD,
			b.WinLost		* e.USD AS WinLostUSD,
			b.LicenseeWL	* e.USD AS LicenseeWLUSD,
			b.Comm			* e.USD AS CommUSD,
			b.PlayerComm	* e.USD AS PlayerCommUSD,
			b.OriginalStake	* e.USD AS OriginalStakeUSD,
			-- EUR
			b.Stake			* e.EUR AS StakeEUR,
			b.Actual_Stake	* e.EUR AS Actual_StakeEUR,
			b.WinLost		* e.EUR AS WinLostEUR,
			b.LicenseeWL	* e.EUR AS LicenseeWLEUR,
			b.Comm			* e.EUR AS CommEUR,
			b.PlayerComm	* e.EUR AS PlayerCommEUR,
			b.OriginalStake	* e.EUR AS OriginalStakeEUR,
			-- GBP
			b.Stake			* e.GBP AS StakeGBP,
			b.Actual_Stake	* e.GBP AS Actual_StakeGBP,
			b.WinLost		* e.GBP AS WinLostGBP,
			b.LicenseeWL	* e.GBP AS LicenseeWLGBP,
			b.Comm			* e.GBP AS CommGBP,
			b.PlayerComm	* e.GBP AS PlayerCommGBP,
			b.OriginalStake	* e.GBP AS OriginalStakeGBP
		FROM #BetListSelAllByDateMem AS b
			INNER JOIN #TempExchange AS e 
				ON e.ExchangeDate = (CASE WHEN b.WinLostDate > @Today THEN @Today ELSE b.WinLostDate END)
					AND e.exchangeid = b.Currency
	) AS T
	WHERE T.RowNum BETWEEN (((@PageIndex - 1) * @PageSize) + 1) AND (@PageSize * @PageIndex)

	-- Get sub tickets
	DECLARE @BettransDetail TABLE (
		RefNo			BIGINT,
		Odds			MONEY,
		Stake			MONEY,
		Status			NVARCHAR(10),
		APositionTaking SMALLMONEY,
		BetType			SMALLINT,
		BetTeam			NVARCHAR(10),
		StakeEUR		MONEY,
		StakeUSD		MONEY,
		StakeGBP		MONEY
	)

	-- Horse Racing
	IF EXISTS (	SELECT 1
				FROM #BetListSelAllByDateMem AS b
					INNER JOIN @SportBettype AS sbt ON b.BetType = sbt.Bettype
				WHERE sbt.ProductID = 2)
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
			INNER JOIN #BetListSelAllByDateMem AS b ON bm.refno = b.TransId
			INNER JOIN #TempExchange AS e ON  e.ExchangeDate = b.WinLostDate AND e.exchangeid = b.currency
			INNER JOIN @SportBettype AS sbt ON b.BetType = sbt.bettype
			INNER JOIN @SportBettype AS sbtm ON bm.bettype = sbtm.Bettype
		WHERE bm.custid = @CustId
			AND sbt.ProductID = 2
			AND sbtm.ProductID = 2
	END

	-- Live Casino
	IF EXISTS (	SELECT 1
				FROM #BetListSelAllByDateMem AS b
					INNER JOIN @SportBettype AS sbt ON b.BetType = sbt.Bettype
				WHERE sbt.ProductId = 4 )
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
			INNER JOIN #BetListSelAllByDateMem AS b ON bg.refno = b.RefNo
			INNER JOIN #TempExchange AS e ON e.ExchangeDate = b.WinLostDate AND e.exchangeid = b.currency
			INNER JOIN @SportBettype AS sbt ON b.BetType = sbt.bettype
			INNER JOIN @SportBettype AS sbtg ON bg.bettype = sbtg.bettype
		WHERE bg.custid = @CustId
			AND sbt.ProductID = 4
			AND sbtg.ProductID = 4
	END

	-- Virtual Sports
	IF EXISTS (	SELECT 1
				FROM #BetListSelAllByDateMem AS b
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
			bm.Betteam,
			bm.stake * e.EUR,
			bm.stake * e.USD,
			bm.stake * e.GBP
		FROM dbo.bettransm AS bm WITH (NOLOCK)
			INNER JOIN #BetListSelAllByDateMem AS b ON bm.refno = b.RefNo
			INNER JOIN #TempExchange AS e ON e.ExchangeDate = b.WinLostDate AND e.exchangeid = b.currency
			INNER JOIN @SportBettype AS sbt ON b.BetType = sbt.bettype
			INNER JOIN @SportBettype AS sbtm ON bm.bettype = sbtm.Bettype
		WHERE bm.custid = @CustId
			AND sbt.ProductId = 5
			AND sbt.EventType = 3
			AND sbtm.ProductId = 5
			AND sbtm.EventType = 3
	END

	SELECT * FROM @BettransDetail
	ORDER BY RefNo
		, Bettype

	DROP TABLE #TempExchange
	DROP TABLE #BetListSelAllByDateMem
END





GO
GRANT  EXECUTE  ON [dbo].[Lrf_BetList_SelAllByDate_Mem]  TO [bodbLicenseeNet]
GO
GRANT VIEW DEFINITION ON [dbo].[Lrf_BetList_SelAllByDate_Mem] TO [vnteam]
GO
