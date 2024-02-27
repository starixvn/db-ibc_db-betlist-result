/*<info serverAlias="DBAGE-bodb02" executers="bodbDownlineNet,bodbDownlineNetView" viewers="" isFunction="0" isNested="0"></info>*/

ALTER PROCEDURE [dbo].[Age_BetList_SelAllByDate_Mem]
	@CustId		INT			= NULL,
	@FromDate	DATETIME,
	@ToDate		DATETIME,
	@Username	VARCHAR(50)	= NULL, -- for API
	@ProductIds	VARCHAR(MAX)
AS

/*
	Created:
	Task: Bet List
	DB: DBAGE.bodb02

	Revisions:
		- 20080707@Viet: Remove Teamname, Leaguename, Sportname, TypeName
		- 20081106@Johnny: Get more result(Sporttype: Horseracing) for betlist
		- 20090226@Hiep: Get more result for Casino Integration
		- 20090402@nqminh: add real_refno column
		- 20090406@HanhVu: remove real_refno 
						- change refno field instead of transid for mix parlay
						- hardcode refno field for single bet
		- 20090415@Henry: Create @BetListSelAllByDateMem temp table, add column BetID to temp table
		- 20090416@Minh: remove indexName
		- 20090421@Henry: Include more columns: comm, acomm, scomm, awinlost, mwinlost, swinlost
		- 20090505@Henry: Change formula of commission
		- 20090522@Henry: More filter: ShowHR, ShowFI. Add F.O Horse Racing bet type (split Sport Book); Get more data from bettransm for HR
		- 20090710@Phuc: unhide IP for TB currency
		- 20090930@Phuc: Show the refunded tickets' status based on bettrans.status/ get oddstype
		- 20100527@Henry: Change to use StatusID instead of Status in WHERE statement
		- 20100611@Henry: Change mix-parlay match from 0 to 9
		- 20100902@Kiwi: Add Number Game & IBCBet Bingo
		- 20101007@Henry: Change column transid from INT to BIGINT
		- 20110307@Lukas: change @ShowHR to @ShowRB & get more sporttype (152,153)
		- 20110408@Amy: Change function to get Odds value and showed odds type
						Display odds value and odds type for Number Game
		- 20110512@Johnson: change column bettype in temporary table from tinyint to smallint
		- 20110801@Sophia: change the range of number game's bettype from 81 to 120, add new bettype 29 for Combination Mix parlay
		- 20110809@Sophia: Not to use function f_GetChoice to get betteam (bettype <> 14, 16)
		- 20110811@Sophia: Add new columns actual_stake and modds
		- 20111122@Sophia: Add Checktime and SecAcceptFlag to show status waiting or running
		- 20111216@Sophia: Remove function f_GetOddsByBettype, f_GetChoice, f_ShowOddsByBettype
		- 20120230@Sophia: Add new bettype: Live Casino, add showtime for Table - Shoe - Hand of LiveCasino
		- 20120405@Hurri: Change bettype for P2P
		- 20120409@Sophia: Remove check checktime with CURRENT_TIMETAMP for Casino, P2P, Bingo
		- 20120419@Lukas: Show transid of main ticket for subticket of system parlay
		- 20120502@Johnson: Get session id(betcheck) for bets list P2P
		- 20120525@Johnson: correct sporttype for p2p
		- 20120626@Elodie: exclude outright, HR from sportbook ( in case of matchid = orid)
		- 20120629@Sophia: Show hdp1 for Number game
		- 20120705@Sophia: Get sporttype for outright
		- 20120807@Sophia: Add new parametter @showVS for Virtual Sports (sporttype = 180 for representing)
						- Remove Financial product
		- 20120926@Sophia: Get comstatus
		- 20130225@Elodie: Add bet list of Virtual HR
		- 20131003@Lukas: sort tickets by transid
		- 20140306@Patrick:	Add more Keno product
		- 20140310@Patrick:	Exclude keno from Sportbook
		- 20140907@Dom:	[Redmine #22012] remove duplicate VS transaction id in bet list feature
		- 20141103@Dom: Apply sport bettype matrix
		- 20150209@Tom: Support 60 BetRadar (27218) Show betcheck coloum on Bettype 216,217
		- 20150522@Bobby: Add GD product
		- 20150526@Bobby: Implement bet list core
		- 20150706@Bobby: #39097 - Fixing bug for showing Keno's bettype info
		- 20150710@Bobby: #39381 - Fixing bug for showing Casino Draw tickets
		- 20150826@Kos: Add column OddsSpread to support Myanmar Odds
		- 20150828@Kos: Support Colossus Bet
		- 20150903@Bobby: Correct data type of sport bet type matrix for avoiding SQL data conversion
		- 20150910@Bobby: Enhance performance for SP core. Apply TVP for input parameters
		- 20151214@Kos: Support Cockfighting [#Redmine: 48850]
		- 20160215@Kos: Support AllBet [#Redmine: 50864]
		- 20160401@Kos: Support Voidbridge [#Redmine: 54643]
		- 20160712@Kos: Change to use inline function for SportBettypeMatrix
		- 20160811@Kos: Support NG2
		- 20161101@Kos: Support Fishing World [#Redmine: 65934]
		- 20170327@Kos: Change input params for Microsite bet list [#Redmine: 66992]
		- 20170703@Kos: Support Betradar Virtual Sports [#Redmine: 77280]
		- 20180201@Kos: Don't support Racing, Live Casino, RNG Casino (bettype 71, 72), Bingo, P2P, Cockfighting [#Redmine: 86086]
		- 20181127@Kos: Enhance performance, don't use core anymore [#Redmine: 103577]
		- 20181227@Kos: Support E-Sports phase 2b [#Redmine: 106456]
		- 20190107@Kos: Support Parlay Changes [#Redmine: 105585]
		- 20190506@Kos: Show match KO time for single ticket [Redmine: #112092]
		- 20190524@Kos: Support BetBuilder [Redmine: #106905]
		- 20190611@Kos: Support Card Club [Redmine: #107645]
					- Don't support Poker Games anymore
					- Remove param @Language
		- 20190722@Kos: Support new status Pending [#Redmine: 113142]
		- 20190829@Kos: Don't support inactive products anymore [Redmine: #119100]
		- 20191028@Kos: Show Running status for Marked tickets [Redmine: 122391]
		- 20191127@Kos: Hotfix - Oddsspread data type [Redmine: #124483]
		- 20191128@Kos: Support Spadegaming [Redmine: #122140]
		- 20191218@Kos: Support Virtual Games [Redmine: #124759]
		- 20200302@Kos: Support SA Gaming [Redmine: #128048]
		- 20200324@Kos: Support Sexy Gaming [Redmine: #130680]
		- 20200331@Kos: Support Saba.club [Redmine: #130769]
		- 20200402@Kos: Support Table Game [Redmine: #129433]
		- 20200422@Kos: Support status Delay Payout [Redmine: #132629]
		- 20200502@Kos: Support Table Game Half Won Half Lose [Redmine: #133323]
		- 20200507@Kos: Support IBCBet Live Casino [Redmine: #130688]
		- 20200514@Kos: Support BBIN [Redmine: #131362]
		- 20200526@Kos: Support RNG War [Redmine: #132017]
		- 20200609@Kos: Support ION [Redmine: #132329]
		- 20200730@Kos: Support PP Jackpot [Redmine: #138482]
		- 20200808@Kos: Support PG Soft [Redmine: #137769]
		- 20200919@Kos: Support Joker [Redmine: #137942]
		- 20201001@Kos: Support WM Live Casino [Redmine: #131588]
		- 20201207@Kos: Support GDG [Redmine: #144104]
		- 20201217@Kos: Support Leap Gaming Virtual Sports 3 [Redmine: #131371]
		- 20201222@Kos: Support Big Gaming [Redmine: #142455]
		- 20201224@Kos: Support Happy 5 Linked Games [Redmine: #146540]
		- 20210114@Razor: Support MaxGame [Redmine: #147568]
		- 20210129@Kos: Support God Of Fortune [Redmine: #149740]
		- 20210202@Kos: Support Saba Promotion [Redmine: #149952]
		- 20210301@Razor: Support Sports Lottery [Redmine: #147368]
		- 20210311@Razor: Support PP Live Casino [Redmine: #134042]
		- 20210319@Razor: Support Habanero [Redmine: #145460]
		- 20210402@Razor: Support CG [Redmine: #146020]
		- 20210429@Razor: Support VGaming [Redmine: #154047]
		- 20210513@Razor: Support AdvantPlay [Redmine: #154259]
		- 20210513@Razor: Support AdvantPlay Mini [Redmine: #155134]
		- 20210705@Razor: Show Odds for Happy 5 Linked Games [Redmine: #154704]
		- 20210706@Razor: Display Decimal Odds for Decimal Odds Only Bettypes [#Redmine: 157545]
		- 20210813@Razor: Support Bitcoin [Redmine: #159041]
		- 20211004@Razor: Extend Data type of IP v6 [Redmine: #90903]
		- 20211125@Razor: Rename RNG War to Funky Games [Redmine: #132024]
		- 20211130@Razor: Support new Cash out model [Redmine: #164903]
		- 20211223@Razor: Support Third Party Result API [Redmine: #165815]
		- 20220124@Razor: Support SG Jackpot [Redmine: #166683]
		- 20220317@Razor: Support FGG [Redmine: #165683]
		- 20220422@Razor: Support Virtual games result [Redmine: #170997]
		- 20220825@Razor: Support SEAL Entertainment [Redmine: #176210]
		- 20220909@Razor: Support Microgaming RNG Casino [Redmine: #175851]
		- 20230206@Razor: Support Jili [Redmine: #182864]
		- 20230526@Razor: Support YeeBet [Redmine: #186547]
		- 20230727@Razor: Support Virtual Sports 3 [Redmine: #189205]
		- 20230909@Razor: Remove GDG, Fishing World products [Redmine: #174511]
		- 20230909@Razor: Remove GD, Colossusbet products [Redmine: #179132]
		- 20231004@Kos: Support Parlay Boost [Redmine: #194992]
		- 20230927@Razor: Support show max payout [Redmine: #194491]
		- 20231027@Razor: Support new bettype of Virtual Sport [Redmine: #194634]
		- 20231101@Razor: Return Device Type info [Redmine: #192667]
		- 20231215@Razor: Support Live22 [Redmine: #197609]
		- 20231129@Razor: Support Project 777 - return LeagueGroupId [Redmine: #194591]
		- 20240228@Razor: Support WE Live Casino [Redmine: #195887]
		- 20240301@Kos: Get original odds for Mix Parlay from ExtraInfo [Redmine: #196425]
*/

BEGIN
	SET NOCOUNT ON;

	-- Get Betradar Virtual Sports in addition to Virtual Sports
	SET @ProductIds = dbo.f_AddRelatedProducts(@ProductIds)

	DECLARE @IsTest BIT = 0

	SELECT @IsTest = dbo.f_CheckSPVersion(@@PROCID)

	DECLARE @Yesterday SMALLDATETIME = DATEADD(DAY, DATEDIFF(DAY, 1, CURRENT_TIMESTAMP), 0)

	CREATE TABLE #MemBetTicket (
		TransId				BIGINT
		, RefNo				BIGINT
		, CustId			INT
		, Username			NVARCHAR(50)
		, SportType			SMALLINT
		, BetType			SMALLINT
		, BetId				BIGINT
		, BetTeam			NVARCHAR(20)
		, Hdp1				SMALLMONEY
		, Hdp2				SMALLMONEY
		, OddsType			TINYINT
		, OddsId			INT
		, Odds				MONEY
		, MOdds				MONEY
		, Stake				MONEY
		, Actual_Stake		MONEY
		, Status			NVARCHAR(10)
		, SettlementStatus	TINYINT
		, TransDate			DATETIME
		, WinLostDate		SMALLDATETIME
		, WinLost			MONEY
		, AWinLost			MONEY
		, MWinLost			MONEY
		, SWinLost			MONEY
		, PlayerComm		MONEY
		, Comm				MONEY
		, AComm				MONEY
		, SComm				MONEY
		, APositionTaking	SMALLMONEY
		, MPositionTaking	SMALLMONEY
		, SPositionTaking	SMALLMONEY
		, TPositionTaking	SMALLMONEY
		, ADiscount			SMALLMONEY
		, MDiscount			SMALLMONEY
		, SDiscount			SMALLMONEY
		, LiveIndicator		BIT
		, LiveHomeScore		SMALLINT
		, LiveAwayScore		SMALLINT
		, FinalHomeScore	SMALLINT
		, FinalAwayScore	SMALLINT
		, HtHomeScore		SMALLINT
		, HtAwayScore		SMALLINT
		, Ip				VARCHAR(45)
		, LeagueId			INT
		, MatchId			INT
		, MatchCode			NVARCHAR(50)
		, Race				NVARCHAR(20)
		, EventDate			DATETIME
		, HomeId			INT
		, AwayId			INT
		, BetStatus			NVARCHAR(50)
		, IsNeutral			BIT
		, Placing			NVARCHAR(20)
		, ShowTime			NVARCHAR(50)
		, BetCheck			NVARCHAR(50)
		, ComStatus			NVARCHAR(20)
		, TransDesc			NVARCHAR(1000)
		, OddsSpread		MONEY
		, BetdaqId			BIGINT
		, ExtraInfo			VARCHAR(1000)
		, Currency			NVARCHAR(50)
		, CurrencyId		TINYINT
		, SiteId			VARCHAR(20)
		, DeviceType		TINYINT
		, LeagueGroupId		SMALLINT
	);

	DECLARE @Tickets TABLE (
		TransId			BIGINT
		, RefNo			BIGINT
		, WinLostDate	SMALLDATETIME
		, Product		VARCHAR(30)
	)

	DECLARE @temp_bettransX TABLE (
		RefNo				BIGINT
		, Odds				MONEY
		, Stake				MONEY
		, Actual_Stake		MONEY
		, Status			NVARCHAR(10)
		, WinLost			MONEY
		, AWinLost			MONEY
		, MWinLost			MONEY
		, SWinLost			MONEY
		, PlayerComm		MONEY
		, Comm				MONEY
		, AComm				MONEY
		, SComm				MONEY
		, APositiontaking	SMALLMONEY
		, MPositiontaking	SMALLMONEY
		, SPositiontaking	SMALLMONEY
		, TPositiontaking	SMALLMONEY
		, Discount			SMALLMONEY
		, ADiscount			SMALLMONEY
		, SDiscount			SMALLMONEY
		, OddsSpread		MONEY
	)

	DECLARE @BettransDetail TABLE (
		RefNo				BIGINT
		, Odds				MONEY
		, Stake				MONEY
		, Status			NVARCHAR(10)
		, APositionTaking	SMALLMONEY
		, MPositionTaking	SMALLMONEY
		, SPositionTaking	SMALLMONEY
		, BetType			SMALLINT
		, BetTeam			NVARCHAR(10)
		, TransDesc			VARCHAR(1000)
	)

	-- bettrans
	INSERT INTO @Tickets (
		TransId,
		RefNo,
		WinLostDate,
		Product
	)
	SELECT
		b.transid,
		b.refno,
		b.winlostdate,
		CASE
			WHEN s.EventType = 0 AND s.ProductID = 1 THEN 'Parlay'		-- Sportsbook Parlay
			WHEN s.EventType = 0 AND s.ProductID = 6 THEN 'OneRNG'		-- RNG Casino
			WHEN s.EventType = 0 AND s.ProductID = 8 THEN 'Keno'
			WHEN s.EventType = 0 AND s.ProductID = 21 THEN 'AllBet'
			WHEN s.EventType = 0 AND s.ProductID = 22 THEN 'VB'			-- Macau Games
			WHEN s.EventType = 0 AND s.ProductID = 23 THEN 'NG2'
			WHEN s.EventType = 0 AND s.ProductID = 27 THEN 'ParlayVS2'	-- Betradar Virtual Sports Parlay
			WHEN s.EventType = 0 AND s.ProductID = 28 THEN 'Lottery'
			WHEN s.EventType = 0 AND s.ProductID = 32 THEN 'PP'			-- Pragmatic Play Casino
			WHEN s.ProductID = 34					THEN 'CC'			-- Card Club
			WHEN s.ProductID = 36					THEN 'SG'			-- Spadegaming
			WHEN s.ProductID = 37					THEN 'SPR'			-- Saba Promotion
			WHEN s.ProductID = 38					THEN 'VRG'			-- Virtual Games
			WHEN s.ProductID = 39					THEN 'SAG'			-- SA Gaming
			WHEN s.ProductID = 40					THEN 'TG'			-- Table Games
			WHEN s.ProductID = 42					THEN 'SBC'			-- Saba.club
			WHEN s.ProductID = 45					THEN 'SXG'			-- Sexy Gaming
			WHEN s.ProductID = 46					THEN 'IBCLC'		-- IBCBet Live Casino
			WHEN s.ProductID = 47					THEN 'BBIN'			-- BBIN
			WHEN s.ProductID = 49					THEN 'VS3'			-- Leap Gaming Virtual Sports 3
			WHEN s.ProductID = 50					THEN 'RNGW'			-- RNG War
			WHEN s.ProductID = 51					THEN 'WM'			-- WM
			WHEN s.ProductID = 52					THEN 'ION'			-- ION
			WHEN s.ProductID = 55					THEN 'PGS'			-- PG Soft
			WHEN s.ProductID = 56					THEN 'JK'			-- Joker
			WHEN s.ProductID = 57					THEN 'BG'			-- Big Gaming
			WHEN s.ProductID = 60					THEN 'MXG'			-- MaxGame
			WHEN s.ProductID = 61					THEN 'HB'			-- Habanero
			WHEN s.ProductID = 62					THEN 'CG'			-- CG
			WHEN s.ProductID = 63					THEN 'SLT'			-- Sports Lottery
			WHEN s.ProductID = 65					THEN 'PPL'			-- PP Live Casino
			WHEN s.ProductID = 66					THEN 'VGA'			-- VGaming
			WHEN s.ProductID = 67					THEN 'AP'			-- AdvantPlay
			WHEN s.ProductID = 68					THEN 'APM'			-- AdvantPlay Min
			WHEN s.ProductID = 69					THEN 'BTC'			-- Bitcoin
			WHEN s.ProductID = 70					THEN 'FGGL'			-- FGG
			WHEN s.ProductID = 72					THEN 'SEA'			-- SEAL Entertainment
			WHEN s.ProductID = 73					THEN 'MGRNG'		-- MG-RNG
			WHEN s.ProductID = 75					THEN 'JIG'			-- Jili
			WHEN s.ProductID = 76					THEN 'YB'			-- YeeBet
			WHEN s.ProductID = 77					THEN 'LG'			-- Virtual Sports 3
			WHEN s.ProductID = 79					THEN 'L22'			-- Live22
			WHEN s.ProductID = 80					THEN 'WE'			-- WE
			WHEN s.EventType = 1 AND s.ProductID = 1 THEN 'SB'			-- Sportsbook
			WHEN s.EventType = 1 AND s.ProductID = 3 THEN 'NG'			-- Number Game
			WHEN s.EventType = 0 AND s.ProductID = 3 THEN 'H5LG'		-- Number Game - Happy 5 Linked Games
			WHEN s.EventType = 1 AND s.ProductID = 5 THEN 'VS'			-- Virtual Sports:: sportsbook
			WHEN s.EventType = 1 AND s.ProductID = 27 THEN 'VS2'		-- Betradar Virtual Sports
			WHEN s.EventType = 2 AND s.ProductID = 1 THEN 'Outright'
			WHEN s.EventType = 3 AND s.ProductID = 5 THEN 'VR'			-- Virtual sports:: racing
			ELSE 'Unknown'
		END AS Product
	FROM dbo.bettrans AS b WITH (NOLOCK)
		INNER JOIN dbo.f_SportBettypeMatrixByProduct_Sel(@ProductIds, @IsTest) AS s ON b.bettype = s.BetType
	WHERE b.custid = @CustId
		AND b.transdate BETWEEN @FromDate AND @ToDate
		AND (s.SubProduct NOT IN ('MG-SuperLive') OR b.StatusId NOT IN (0, 1))

	DELETE FROM @Tickets WHERE Product = 'Unknown'

	IF EXISTS (SELECT 1 FROM @Tickets)
	BEGIN
		-- bettransRnG
		IF EXISTS (SELECT 1 FROM @Tickets WHERE Product IN ('VB', 'PP', 'OneRNG', 'CC', 'SG', 'SBC', 'RNGW', 'PGS', 'JK', 'MXG', 'HB', 'CG', 'VGA', 'AP', 'APM', 'SEA', 'MGRNG', 'JIG', 'L22') AND WinLostDate >= @Yesterday)
		BEGIN
			-- Running
			INSERT INTO @temp_bettransX
			SELECT
				c.TransId AS RefNo,
				0 AS Odds,
				SUM(brng.stake) AS Stake,
				SUM(brng.actual_stake) AS Actual_Stake,
				'Running' AS Status,
				0 AS WinLost,
				0 AS AWinLost,
				0 AS MWinLost,
				0 AS SWinLost,
				0 AS PlayerComm,
				0 AS Comm,
				0 AS AComm,
				0 AS SComm,
				AVG(brng.APositiontaking) AS APositiontaking,
				AVG(brng.MPositiontaking) AS MPositiontaking,
				AVG(brng.SPositiontaking) AS SPositiontaking,
				AVG(brng.TPositiontaking) AS TPositiontaking,
				AVG(brng.discount) AS Discount,
				AVG(brng.adiscount) AS ADiscount,
				AVG(brng.sdiscount) AS SDiscount,
				0 AS OddsSpread
			FROM @Tickets AS c
				INNER JOIN dbo.bettransRnG AS brng WITH (NOLOCK) ON brng.RefNo = c.TransId
			WHERE c.Product IN ('VB', 'PP', 'OneRNG', 'CC', 'SG', 'SBC', 'RNGW', 'PGS', 'JK', 'MXG', 'HB', 'CG', 'VGA', 'AP', 'APM', 'SEA', 'MGRNG', 'JIG', 'L22')
				AND c.WinLostDate >= @Yesterday
				AND brng.statusID IN (0, 1)
			GROUP BY
				c.TransId,
				c.Product

			-- Settled
			INSERT INTO @temp_bettransX
			SELECT
				c.TransId AS RefNo,
				CASE
					WHEN Product IN ('OneRNG', 'PP', 'SG') THEN ISNULL(AVG(CASE WHEN brng.statusID IN (111, 112, 113) THEN brng.ContributionRate END), 0)
					ELSE 0
				END AS Odds,
				SUM(brng.stake) AS Stake,
				SUM(brng.actual_stake) AS Actual_Stake,
				CASE
					WHEN SUM(brng.winlost - brng.actual_stake) > 0 THEN 'Won'
					WHEN SUM(brng.winlost - brng.actual_stake) < 0 THEN 'Lose'
					ELSE 'Draw'
				END AS Status,
				SUM(brng.winlost - brng.actual_stake) AS WinLost,
				SUM(brng.awinlost) AS AWinLost,
				SUM(brng.mwinlost) AS MWinLost,
				SUM(brng.swinlost) AS SWinLost,
				SUM(brng.playercomm) AS PlayerComm,
				SUM(brng.comm - brng.playercomm) AS Comm,
				SUM(brng.acomm - brng.comm) AS AComm,
				SUM(brng.scomm - brng.acomm) AS SComm,
				AVG(brng.APositiontaking) AS APositiontaking,
				AVG(brng.MPositiontaking) AS MPositiontaking,
				AVG(brng.SPositiontaking) AS SPositiontaking,
				AVG(brng.TPositiontaking) AS TPositiontaking,
				AVG(brng.discount) AS Discount,
				AVG(brng.adiscount) AS ADiscount,
				AVG(brng.sdiscount) AS SDiscount,
				CASE
					WHEN c.Product IN ('OneRNG', 'PP', 'SG') THEN ISNULL(SUM(brng.BetStake), 0)
					ELSE 0
				END AS OddsSpread
			FROM @Tickets AS c
				INNER JOIN dbo.bettransRnG AS brng WITH (NOLOCK) ON brng.RefNo = c.TransId
			WHERE c.Product IN ('VB', 'PP', 'OneRNG', 'CC', 'SG', 'SBC', 'RNGW', 'PGS', 'JK', 'MXG', 'HB', 'CG', 'VGA', 'AP', 'APM', 'SEA', 'MGRNG', 'JIG', 'L22')
				AND c.WinLostDate >= @Yesterday
				AND brng.statusID NOT IN (0, 1)
			GROUP BY
				c.TransId,
				c.Product
		END

		-- bettransLC
		IF EXISTS (SELECT 1 FROM @Tickets WHERE Product IN ('Allbet', 'SAG', 'SXG', 'IBCLC', 'ION', 'WM', 'BG', 'PPL', 'FGGL', 'YB', 'WE') AND WinLostDate >= @Yesterday)
		BEGIN
			-- Running
			INSERT INTO @temp_bettransX
			SELECT
				c.TransId AS RefNo,
				0 AS Odds,
				SUM(blc.stake) AS Stake,
				SUM(blc.actual_stake) AS Actual_Stake,
				'Running' AS Status,
				0 AS WinLost,
				0 AS AWinLost,
				0 AS MWinLost,
				0 AS SWinLost,
				0 AS PlayerComm,
				0 AS Comm,
				0 AS AComm,
				0 AS SComm,
				AVG(blc.APositiontaking) AS APositiontaking,
				AVG(blc.MPositiontaking) AS MPositiontaking,
				AVG(blc.SPositiontaking) AS SPositiontaking,
				AVG(blc.TPositiontaking) AS TPositiontaking,
				AVG(blc.discount) AS Discount,
				AVG(blc.adiscount) AS ADiscount,
				AVG(blc.sdiscount) AS SDiscount,
				0 AS OddsSpread
			FROM @Tickets AS c
				INNER JOIN dbo.bettransLC AS blc WITH (NOLOCK) ON blc.RefNo = c.TransId
			WHERE c.Product IN ('Allbet', 'SAG', 'SXG', 'IBCLC', 'ION', 'WM', 'BG', 'PPL', 'FGGL', 'YB', 'WE')
				AND c.WinLostDate >= @Yesterday
				AND blc.statusID IN (0, 1)
			GROUP BY
				c.TransId,
				c.Product

			-- Settled
			INSERT INTO @temp_bettransX
			SELECT
				c.TransId AS RefNo,
				0 AS Odds,
				SUM(blc.stake) AS Stake,
				SUM(blc.actual_stake) AS Actual_Stake,
				CASE
					WHEN SUM(blc.winlost - blc.actual_stake) > 0 THEN 'Won'
					WHEN SUM(blc.winlost - blc.actual_stake) < 0 THEN 'Lose'
					ELSE 'Draw'
				END AS Status,
				SUM(blc.winlost - blc.actual_stake) AS WinLost,
				SUM(blc.awinlost) AS AWinLost,
				SUM(blc.mwinlost) AS MWinLost,
				SUM(blc.swinlost) AS SWinLost,
				SUM(blc.playercomm) AS PlayerComm,
				SUM(blc.comm - blc.playercomm) AS Comm,
				SUM(blc.acomm - blc.comm) AS AComm,
				SUM(blc.scomm - blc.acomm) AS SComm,
				AVG(blc.APositiontaking) AS APositiontaking,
				AVG(blc.MPositiontaking) AS MPositiontaking,
				AVG(blc.SPositiontaking) AS SPositiontaking,
				AVG(blc.TPositiontaking) AS TPositiontaking,
				AVG(blc.discount) AS Discount,
				AVG(blc.adiscount) AS ADiscount,
				AVG(blc.sdiscount) AS SDiscount,
				0 AS OddsSpread
			FROM @Tickets AS c
				INNER JOIN dbo.bettransLC AS blc WITH (NOLOCK) ON blc.RefNo = c.TransId
			WHERE c.Product IN ('Allbet', 'SAG', 'SXG', 'IBCLC', 'ION', 'WM', 'BG', 'PPL', 'FGGL', 'YB', 'WE')
				AND c.WinLostDate >= @Yesterday
				AND blc.statusID NOT IN (0, 1)
			GROUP BY
				c.TransId,
				c.Product
		END

		INSERT INTO #MemBetTicket
		SELECT TransId = CASE
							WHEN c.Product = 'Parlay' AND b.bettype = 29 AND ISNULL(b.betid, 0) > 0 THEN b.betid
							ELSE b.transid
						END 
			,RefNo = b.refno
			,CustId = b.custid
			,Username = b.username
			,SportType = CASE
							WHEN c.Product IN ('OneRNG', 'CC', 'SG', 'VRG', 'SAG', 'TG', 'SBC', 'SXG', 'IBCLC', 'BBIN', 'RNGW', 'ION', 'PGS', 'JK', 'WM', 'VS3', 'BG', 'H5LG', 
								'MXG', 'SPR', 'SLT', 'PPL', 'HB', 'CG', 'VGA', 'AP', 'APM', 'FGGL', 'SEA', 'MGRNG', 'JIG', 'YB', 'L22', 'WE') THEN b.matchid
							WHEN c.Product = 'Keno' THEN 202
							WHEN c.Product = 'AllBet' THEN 211 -- AllBet
							WHEN c.Product = 'VB' THEN 212 -- Macau Games
							WHEN c.Product = 'NG2' AND b.bettype BETWEEN 2501 AND 2539 THEN 213 -- NG2
							WHEN c.Product = 'NG2' AND b.bettype BETWEEN 2541 AND 2579 THEN 214 -- NG2
							WHEN c.Product = 'NG2' AND b.bettype BETWEEN 2581 AND 2619 THEN 215 -- NG2
							WHEN c.Product = 'NG2' AND b.bettype BETWEEN 2621 AND 2659 THEN 216 -- NG2
							WHEN c.Product = 'NG2' AND b.bettype BETWEEN 2681 AND 2699 THEN 218 -- NG2
							WHEN c.Product = 'Lottery' THEN 220 -- Lottery
							WHEN c.Product = 'PP' THEN 248 -- Pragmatic Casino
							WHEN c.Product IN ('SB', 'NG', 'VS', 'VS2', 'LG') THEN m.sporttype
							WHEN c.Product IN ('Outright') THEN l.sporttype
							WHEN c.Product IN ('VR') THEN vr.SportType
							WHEN c.Product IN ('BTC') THEN m3rd.SportType
							ELSE 0
						END
			,BetType = b.bettype
			,BetId = ISNULL(b.betid, 0)
			,BetTeam = CASE
							WHEN c.Product IN ('SB', 'NG', 'VS', 'VS2', 'Parlay', 'ParlayVS2', 'BTC', 'LG') THEN b.betteam
							ELSE ''
						END
			,Hdp1 = CASE
						WHEN c.Product IN ('Parlay', 'ParlayVS2', 'NG2') THEN b.hdp1 -- parlay(s), NG2
						WHEN c.Product IN ('SB', 'NG', 'VS', 'VS2', 'BTC', 'LG') THEN b.hdp1
						WHEN c.Product IN ('VR') THEN b.hdp1
						ELSE 0
					END
			,Hdp2 = CASE
						WHEN c.Product IN ('Parlay', 'ParlayVS2', 'NG2') THEN b.hdp2 --parlay(s), NG2
						WHEN c.Product IN ('SB', 'VS', 'VS2', 'LG') THEN b.hdp2
						WHEN c.Product IN ('VR') THEN b.hdp2
						ELSE 0
					END
			,OddsType = CASE
							WHEN c.Product IN ('SB', 'Outright', 'NG', 'VS', 'VS2', 'Keno', 'LG') THEN b.oddstype
							ELSE 0
						END
			,OddsId = b.oddsid
			,Odds = CASE 
						WHEN c.Product IN ('Parlay', 'OneRNG', 'PP', 'SG', 'Keno', 'NG2', 'ParlayVS2', 'Lottery', 'VRG', 'TG', 'VS3', 'H5LG', 'SLT', 'BTC') THEN b.Odds
						WHEN c.Product IN ('SB', 'NG', 'VS', 'VS2', 'LG') THEN b.odds
						WHEN c.Product IN ('Outright') THEN b.odds
						WHEN c.Product IN ('VR') THEN b.odds
						ELSE 0 END
			,MOdds = CASE 
						WHEN c.Product IN ('Parlay', 'ParlayVS2')  THEN b.modds 
						WHEN c.Product IN ('SB', 'NG', 'VS', 'VS2', 'LG') THEN b.modds
						WHEN c.Product IN ('Outright') THEN b.modds
						WHEN c.Product IN ('VR') THEN b.modds
						ELSE 0 END
			,Stake = b.stake
			,Actual_Stake = b.actual_stake
			,Status = CASE
						WHEN c.Product = 'SB' AND b.bettype NOT IN (9, 29)
							AND b.status = 'running' AND ISNULL(b.SecAcceptFlag, 0) = 1 AND ISNULL(b.checktime, CURRENT_TIMESTAMP) > CURRENT_TIMESTAMP THEN 'waiting'
						WHEN b.bettype IN (9, 29, 2799) AND b.status = 'running' THEN
							CASE
								WHEN EXISTS (SELECT 1 FROM dbo.bettransm AS bm WITH (NOLOCK)
											WHERE bm.custid = b.custid
												AND bm.refno = b.refno
												AND (bm.status = 'waiting'
													OR (bm.status = 'running' AND ISNULL(bm.SecAcceptFlag, 0) = 1 AND ISNULL(bm.checktime, CURRENT_TIMESTAMP) > CURRENT_TIMESTAMP)))
									THEN 'Waiting'
								ELSE b.status
							END
						WHEN c.Product = 'TG' AND b.status = 'Won' AND b.modds = 0.25 THEN 'Half Won'
						WHEN c.Product = 'TG' AND b.status = 'Lose' AND b.modds = -0.25 THEN 'Half Lose'
						ELSE b.status
					END
			,SettlementStatus = CASE
									WHEN c.Product = 'SB' THEN ISNULL(m.SettlementStatus, 0)
									ELSE 0
								END
			,TransDate = b.transdate
			,WinLostDate = b.winlostdate
			,WinLost = b.winlost - b.actual_stake
			,AWinLost = b.awinLost
			,MWinLost = b.mwinLost
			,SWinLost = b.SwinLost
			,PlayerComm = b.playercomm
			,Comm = b.comm - b.playercomm
			,AComm = b.acomm - b.comm
			,SComm = b.scomm - b.acomm
			,APositionTaking = b.APositiontaking
			,MPositionTaking = b.MPositiontaking
			,SPositionTaking = b.SPositiontaking
			,TPositionTaking = b.TPositiontaking
			,ADiscount = b.discount
			,MDiscount = b.adiscount
			,SDiscount = b.sdiscount
			,LiveIndicator = CASE 
								WHEN c.Product IN ('Parlay') THEN b.Liveindicator 
								WHEN c.Product IN ('SB', 'NG', 'VS', 'VS2', 'LG') THEN b.liveindicator
								ELSE 0 END
			,LiveHomeScore = CASE 
								WHEN c.Product IN ('Parlay', 'NG2') THEN b.Livehomescore
								WHEN c.Product IN ('SB', 'NG', 'VS', 'VS2', 'LG') THEN b.livehomescore
								WHEN c.Product IN ('Outright') THEN b.livehomescore
								WHEN c.Product IN ('VR') THEN b.livehomescore
								ELSE 0 END
			,LiveAwayScore = CASE 
								WHEN c.Product IN ('Parlay') THEN b.Liveawayscore 
								WHEN c.Product IN ('SB', 'NG', 'VS', 'VS2', 'LG') THEN b.liveawayscore
								WHEN c.Product IN ('Outright') THEN b.liveawayscore
								WHEN c.Product IN ('VR') THEN b.liveawayscore
								ELSE 0 END
			,FinalHomeScore = CASE
									WHEN c.Product IN ('SB', 'NG', 'VS', 'VS2', 'LG') THEN m.finalhomescore
									ELSE 0 END
			,FinalAwayScore = CASE
									WHEN c.Product IN ('SB', 'NG', 'VS', 'VS2', 'LG') THEN m.finalawayscore
									ELSE 0 END
			,HtHomeScore = CASE
								WHEN c.Product IN ('SB', 'NG', 'VS', 'VS2', 'LG') THEN m.hthomescore
								ELSE 0 END
			,HtAwayScore = CASE
								WHEN c.Product IN ('SB', 'NG', 'VS', 'VS2', 'LG') THEN m.htawayscore
								ELSE 0 END
			,Ip = b.ip
			,LeagueId = CASE
							WHEN c.Product IN ('SB', 'NG', 'VS', 'VS2', 'LG') THEN m.leagueid
							WHEN c.Product IN ('Outright') THEN o.leagueid
							WHEN c.Product IN ('VR') THEN vr.LeagueID
							ELSE 0 END
			,MatchId = CASE
							WHEN c.Product IN ('NG2') THEN b.betdaqid
							WHEN c.Product IN ('SB', 'NG', 'VS', 'VS2', 'LG') THEN m.matchid
							WHEN c.Product IN ('Outright') THEN o.orid
							WHEN c.Product IN ('VR', 'BTC') THEN b.matchid
							ELSE 0 END
			,MatchCode = CASE
							WHEN c.Product IN ('SB', 'NG', 'VS', 'VS2', 'LG') THEN m.matchcode
							WHEN c.Product IN ('Outright') THEN o.matchcode
							WHEN c.Product IN ('VR') THEN CONVERT(NVARCHAR(50), vo.RacerNum)
							ELSE '' END
			,Race = CASE
							WHEN c.Product IN ('Outright') THEN o.groupmatch
							WHEN c.Product IN ('VR') THEN CONVERT(NVARCHAR(50), b.oddsid)
							ELSE '' END
			,EventDate = CASE
							WHEN c.Product = 'SB' THEN m.GlobalShowTime
							WHEN c.Product IN ('NG', 'VS', 'VS2', 'LG') THEN m.eventdate
							WHEN c.Product IN ('Outright') THEN o.eventdate
							WHEN c.Product IN ('VR') THEN vo.EventDate
							WHEN c.Product IN ('BTC') THEN m3rd.EndTime
							ELSE b.winlostdate END
			,HomeId = CASE
							WHEN c.Product IN ('SB', 'NG', 'VS', 'VS2', 'LG') THEN m.homeid
							WHEN c.Product IN ('Outright') THEN o.teamid
							WHEN c.Product IN ('VR') THEN vo.RacerID
							ELSE 0 END
			,AwayId = CASE
							WHEN c.Product IN ('SB', 'NG', 'VS', 'VS2', 'LG') THEN m.awayid
							ELSE 0 END
			,BetStatus = CASE
							WHEN c.Product IN ('SB', 'NG', 'VS', 'VS2', 'LG') THEN m.betstatus
							ELSE '' END
			,IsNeutral = CASE
							WHEN c.Product IN ('SB', 'NG', 'VS', 'VS2', 'LG') THEN ISNULL(m.IsNeutral, 0)
							ELSE 0 END
			,Placing = CASE
							WHEN c.Product IN ('VR') THEN CONVERT(VARCHAR(5), vo.Placing)
							ELSE '' END
			,ShowTime = CASE
							WHEN c.Product IN ('VS', 'VS2', 'LG') THEN CONVERT(NVARCHAR(50), m.kickofftime)
							WHEN c.Product IN ('SB', 'NG') THEN ISNULL(m.showtime, '')
							WHEN c.Product IN ('VR') THEN CONVERT(NVARCHAR(50), vr.EventTime)
							ELSE '' END
			,BetCheck = CASE 
							WHEN c.Product IN ('SB', 'Parlay', 'ParlayVS2', 'VRG', 'H5LG', 'SLT') THEN ISNULL(b.betcheck, '')
							WHEN c.Product IN ('Keno') THEN ISNULL(b.comstatus, '')
							ELSE '' END
			,ComStatus = CASE WHEN b.comstatus = '1' THEN '1' ELSE '0' END
			,TransDesc = CASE
							WHEN c.Product IN ('OneRNG', 'CC', 'SG', 'Keno', 'VB', 'NG2', 'Lottery', 'PP', 'VRG', 'TG', 'PGS', 'JK', 'SLT', 'HB', 'CG', 'AP', 'APM', 'SEA') THEN b.transdesc
							WHEN c.Product IN ('SB', 'VS2', 'VS3', 'H5LG', 'LG') THEN ISNULL(b.transdesc, '')
							ELSE '' END
			,OddsSpread = CASE
							WHEN c.Product IN ('SB', 'OneRNG', 'PP', 'SG', 'Parlay') THEN ISNULL(b.oddsspread, 0)
							ELSE 0 END
			,BetdaqId = CASE
							WHEN c.Product IN ('SB') THEN ISNULL(b.betdaqid, -1)
							ELSE -1
						END
			,ExtraInfo = ISNULL(b.ExtraInfo, '')
			,Currency = b.currencyname
			,CurrencyId = CASE
							WHEN c.Product IN ('H5LG', 'SLT') THEN b.currency
							ELSE 0
						END
			,SiteId = CASE
						WHEN c.Product IN ('VRG', 'H5LG', 'SLT') THEN CONVERT(VARCHAR(20), b.betdaqid)
						ELSE ''
					END
			,DeviceType = b.DeviceType
			,LeagueGroupId = le.LeagueGroupId
		FROM @Tickets AS c
			INNER JOIN dbo.bettrans AS b WITH (NOLOCK) ON b.transid = c.TransId
			LEFT JOIN dbo.match AS m WITH (NOLOCK) ON c.Product IN ('SB', 'NG', 'VS', 'VS2', 'LG') AND b.matchid = m.matchid
			LEFT JOIN dbo.outright AS o WITH (NOLOCK) ON c.Product IN ('Outright') AND b.matchid = o.orid
			LEFT JOIN dbo.League AS l WITH (NOLOCK) ON c.Product IN ('Outright') AND o.leagueid = l.leagueid
			LEFT JOIN dbo.VSOutright AS vo WITH (NOLOCK) ON c.Product IN ('VR') AND b.oddsid = vo.Orid
			LEFT JOIN dbo.VSRaceInfo AS vr WITH (NOLOCK) ON c.Product IN ('VR') AND vr.EventID = vo.EventID
			LEFT JOIN dbo.match3rd AS m3rd WITH (NOLOCK) ON b.matchid = m3rd.match3rdid
			LEFT JOIN dbo.League AS le WITH (NOLOCK) ON m.leagueid = le.leagueid
		WHERE c.Product NOT IN ('VB', 'PP', 'OneRNG', 'CC', 'SG', 'SBC', 'RNGW', 'PGS', 'JK', 'MXG', 'HB', 'CG', 'VGA', 'AP', 'APM', 'SEA', 'MGRNG', 'JIG', 'L22', 'Allbet', 'SAG', 'SXG', 'IBCLC', 'ION', 'WM', 'BG', 'PPL', 'FGGL', 'YB', 'WE')
			OR c.WinLostDate < @Yesterday

		-- Get final odds, boost rate for settled Mix Parlay tickets
		IF EXISTS (SELECT 1 FROM #MemBetTicket WHERE BetType = 29 AND BetTeam = '1')
		BEGIN
			UPDATE b
			SET
				b.Modds = bpr.mOdds,
				b.TransDesc = CONVERT(VARCHAR(20), ISNULL(bpr.ExtraValue, ''))
			FROM #MemBetTicket AS b
				INNER JOIN dbo.BetParlayResult AS bpr WITH (NOLOCK) ON bpr.RefNo = b.RefNo
			WHERE b.BetType = 29
				AND b.BetTeam = '1'
				AND b.Status NOT IN ('Running', 'Waiting')
		END

		INSERT INTO #MemBetTicket
		SELECT TransId = b.transid
			,RefNo = b.refno
			,CustId = b.custid
			,Username = b.username
			,SportType = CASE
							WHEN c.Product IN ('OneRNG', 'CC', 'SG', 'SAG', 'SBC', 'RNGW', 'SXG', 'IBCLC', 'ION', 'PGS', 'JK', 'WM', 'BG', 'MXG', 'PPL', 'HB', 'CG', 'VGA', 'AP', 'APM', 'FGGL', 'SEA', 'MGRNG', 'JIG', 'YB', 'L22', 'WE') THEN b.matchid
							WHEN c.Product = 'AllBet' THEN 211 -- AllBet
							WHEN c.Product = 'VB' THEN 212 -- Macau Games
							WHEN c.Product = 'PP' THEN 248 -- Pragmatic Casino
							ELSE 0
						END
			,BetType = b.bettype
			,BetId = ISNULL(b.betid, 0)
			,BetTeam = ''
			,Hdp1 = 0
			,Hdp2 = 0
			,OddsType = 0
			,OddsId = b.oddsid
			,Odds = x.Odds
			,MOdds = 0
			,Stake = x.Stake
			,Actual_Stake = x.Actual_Stake
			,Status = x.status
			,SettlementStatus = 0
			,TransDate = b.transdate
			,WinLostDate = b.winlostdate
			,WinLost = x.WinLost
			,AWinLost = x.AWinLost
			,MWinLost = x.MWinLost
			,SWinLost = x.SWinLost
			,PlayerComm = x.PlayerComm
			,Comm = x.Comm
			,AComm = x.AComm
			,SComm = x.SComm
			,APositionTaking = x.APositiontaking
			,MPositionTaking = x.MPositiontaking
			,SPositionTaking = x.SPositiontaking
			,TPositionTaking = x.TPositiontaking
			,ADiscount = x.discount
			,MDiscount = x.adiscount
			,SDiscount = x.sdiscount
			,LiveIndicator = 0
			,LiveHomeScore = 0
			,LiveAwayScore = 0
			,FinalHomeScore = 0
			,FinalAwayScore = 0
			,HtHomeScore = 0
			,HtAwayScore = 0
			,Ip = b.ip
			,LeagueId = 0
			,MatchId = 0
			,MatchCode = ''
			,Race = ''
			,EventDate = b.winlostdate
			,HomeId = 0
			,AwayId = 0
			,BetStatus = ''
			,IsNeutral = 0
			,Placing = ''
			,ShowTime = ''
			,BetCheck = ''
			,ComStatus = CASE WHEN b.comstatus = '1' THEN '1' ELSE '0' END
			,TransDesc = CASE
							WHEN c.Product IN ('OneRNG', 'VB', 'PP', 'CC', 'SG', 'PGS', 'JK', 'HB', 'CG', 'AP', 'APM', 'SEA') THEN b.transdesc
							ELSE '' END
			,OddsSpread = CASE
							WHEN c.Product IN ('OneRNG', 'PP', 'SG') THEN x.OddsSpread
							ELSE 0 END
			,BetdaqId = -1
			,ExtraInfo = ''
			,Currency = b.currencyname
			,CurrencyId = b.currency
			,SiteId = b.betdaqid
			,DeviceType = b.DeviceType
			,LeagueGroupId = 0
		FROM @Tickets AS c
			INNER JOIN dbo.bettrans AS b WITH (NOLOCK) ON b.transid = c.TransId
			INNER JOIN @temp_bettransX AS x ON x.RefNo = c.TransId
		WHERE c.Product IN ('VB', 'PP', 'OneRNG', 'CC', 'SG', 'SBC', 'RNGW', 'PGS', 'JK', 'MXG', 'HB', 'CG', 'VGA', 'AP', 'APM', 'SEA', 'MGRNG', 'JIG', 'L22', 'Allbet', 'SAG', 'SXG', 'IBCLC', 'ION', 'WM', 'BG', 'PPL', 'FGGL', 'YB', 'WE')
			AND c.WinLostDate >= @Yesterday

		-- Virtual Sports Racing
		INSERT INTO @BettransDetail
		SELECT RefNo = bm.refno
			,Odds = bm.odds
			,Stake = bm.stake
			,Status = bm.status
			,APositionTaking = bm.apositiontaking
			,MPositionTaking = bm.mpositiontaking
			,SPositionTaking = bm.spositiontaking
			,BetType = bm.bettype
			,BetTeam = bm.betteam
			,TransDesc = ''
		FROM @Tickets AS c
			INNER JOIN dbo.bettransm AS bm WITH (NOLOCK) ON c.RefNo = bm.refno
		WHERE c.Product = 'VR' AND bm.custid = @CustId
	
	END

	DELETE FROM @Tickets

	-- translog
	INSERT INTO @Tickets (
		TransId,
		RefNo,
		WinLostDate,
		Product
	)
	SELECT
		b.translogid AS TransId,
		b.translogid AS RefNo,
		b.winlostdate,
		CASE
			WHEN s.BetType BETWEEN 801 AND 899 THEN 'MG'			-- Metric Gaming
			WHEN s.EventType = 0 AND s.ProductID = 3 THEN 'H5LG'	-- Number Game - Happy 5 Linked Games
			WHEN s.ProductID = 8 THEN 'Keno'
			WHEN s.ProductID = 28 THEN 'Lottery'
			WHEN s.ProductID = 38 THEN 'VRG'		-- Virtual Games
			WHEN s.ProductID = 40 THEN 'TG'			-- Table Games
			WHEN s.ProductID = 49 THEN 'VS3'		-- Leap Gaming Virtual Sports 3
			WHEN s.ProductID = 63 THEN 'SLT'		-- Sports Lottery
			ELSE 'Unknown'
		END AS Product
	FROM dbo.translog AS b WITH (NOLOCK)
		INNER JOIN dbo.f_SportBettypeMatrixByProduct_Sel(@ProductIds, @IsTest) AS s ON b.gameID = s.bettype
	WHERE b.custid = @CustId
		AND b.transdate BETWEEN @FromDate AND @ToDate
		AND b.statusID IN (0, 1)
		AND (s.ProductID IN (8, 28, 38, 40, 63)
			OR s.BetType BETWEEN 801 AND 899
			OR (s.ProductID = 3 AND s.EventType = 0))

	DELETE FROM @Tickets WHERE Product = 'Unknown'

	IF EXISTS (SELECT 1 FROM @Tickets)
	BEGIN
		INSERT INTO #MemBetTicket
		SELECT TransId = b.translogid
			,RefNo = b.translogid
			,CustId = b.custid
			,Username = b.username
			,SportType = CASE
							WHEN c.Product = 'Keno' THEN 202
							WHEN c.Product = 'Lottery' THEN 220					-- Lottery
							WHEN c.Product IN ('VRG', 'TG', 'VS3', 'H5LG', 'SLT') THEN b.productID	-- Virtual Games, Tables Games
							WHEN c.Product = 'MG' THEN m.sporttype
							ELSE 0
						END
			,BetType = b.gameID
			,BetId = 0
			,BetTeam = ''
			,Hdp1 = 0
			,Hdp2 = 0
			,OddsType = CASE 
							WHEN c.Product IN ('MG') THEN CONVERT(TINYINT, ISNULL(b.custom1, 0))
							ELSE 0 END
			,OddsId = 0
			,Odds = b.odds
			,MOdds = 0
			,Stake = b.stake
			,Actual_Stake = b.actual_stake
			,Status = b.status
			,SettlementStatus = CASE
									WHEN c.Product IN ('MG') THEN ISNULL(m.SettlementStatus, 0)
									ELSE 0
								END
			,TransDate = b.transdate
			,WinLostDate = b.winlostdate
			,WinLost = 0
			,AWinLost = 0
			,MWinLost = 0
			,SWinLost = 0
			,PlayerComm = 0
			,Comm = 0
			,AComm = 0
			,SComm = 0
			,APositionTaking = b.APositiontaking
			,MPositionTaking = b.MPositiontaking
			,SPositionTaking = b.SPositiontaking
			,TPositionTaking = b.TPositiontaking
			,ADiscount = b.discount
			,MDiscount = b.adiscount
			,SDiscount = b.sdiscount
			,LiveIndicator = 0
			,LiveHomeScore = 0
			,LiveAwayScore = 0
			,FinalHomeScore = CASE
									WHEN c.Product IN ('MG') THEN m.finalhomescore
									ELSE 0 END
			,FinalAwayScore = CASE
									WHEN c.Product IN ('MG') THEN m.finalawayscore
									ELSE 0 END
			,HtHomeScore = CASE
								WHEN c.Product IN ('MG') THEN m.hthomescore
								ELSE 0 END
			,HtAwayScore = CASE
								WHEN c.Product IN ('MG') THEN m.htawayscore
								ELSE 0 END
			,Ip = b.ip
			,LeagueId = CASE
							WHEN c.Product IN ('MG') THEN m.leagueid
							ELSE 0 END
			,MatchId = CASE
							WHEN c.Product IN ('MG') THEN m.matchid
							ELSE 0 END
			,MatchCode = CASE
							WHEN c.Product IN ('MG') THEN m.matchcode
							ELSE '' END
			,Race = ''
			,EventDate = CASE
							WHEN c.Product IN ('MG') THEN m.GlobalShowTime
							ELSE b.winlostdate END
			,HomeId = CASE
							WHEN c.Product IN ('MG') THEN m.homeid
							ELSE 0 END
			,AwayId = CASE
							WHEN c.Product IN ('MG') THEN m.awayid
							ELSE 0 END
			,BetStatus = CASE
							WHEN c.Product IN ('MG') THEN m.betstatus
							ELSE '' END
			,IsNeutral = CASE
							WHEN c.Product IN ('MG') THEN ISNULL(m.IsNeutral, 0)
							ELSE 0 END
			,Placing = ''
			,ShowTime = CASE
							WHEN c.Product IN ('MG') THEN ISNULL(m.showtime, '')
							ELSE '' END
			,BetCheck = CASE 
							WHEN c.Product IN ('VRG', 'H5LG', 'SLT') THEN b.Gameid3rd
							WHEN c.Product IN ('Keno') THEN ISNULL(b.custom2, '')
							WHEN c.Product IN ('VS3') THEN ISNULL(b.custom1, '')
							ELSE '' END
			,ComStatus = 0
			,TransDesc = CASE
							WHEN c.Product IN ('MG', 'Keno', 'Lottery', 'VRG', 'TG', 'VS3', 'H5LG', 'SLT') THEN b.transdesc
							ELSE '' END
			,OddsSpread = 0
			,BetdaqId = -1
			,ExtraInfo = ''
			,Currency = b.currencyname
			,CurrencyId = CASE
							WHEN c.Product IN ('H5LG', 'SLT') THEN b.currency
							ELSE 0
						END
			,SiteId = CASE
						WHEN c.Product IN ('VRG', 'H5LG', 'SLT') THEN b.SiteId
						ELSE ''
					END
			,DeviceType = b.DeviceType
			,LeagueGroupId = 0
		FROM @Tickets AS c
			INNER JOIN dbo.translog AS b WITH (NOLOCK) ON b.translogid = c.transid
			LEFT JOIN dbo.match AS m WITH (NOLOCK) ON c.Product IN ('MG') AND b.eventid = m.matchid

	END

	SELECT *
	FROM #MemBetTicket
	ORDER BY TransId DESC

	-- OUTPUT ticket detail
	SELECT *
	FROM @BettransDetail
	ORDER BY RefNo DESC

	DROP TABLE #MemBetTicket
END
GO
