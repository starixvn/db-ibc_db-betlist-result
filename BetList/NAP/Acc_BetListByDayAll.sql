/*<info serverAlias="DBAGE-bodb02" executers="wsv_nap" viewers="" isFunction="0" isNested="0"></info>*/

ALTER PROCEDURE [dbo].[Acc_BetListByDayAll]
	@CustId			INT,
	@FromDate		SMALLDATETIME,
	@MoveBetsDay	DATETIME,
	@TransType		INT				= 0
AS

/*
	Created by: [Creator]
	Date: 2008
	Task: Bet list by date
	DB: DBAGE.bodb02
	
	Revisions:
		- 20081218@PhuongNguyen: Get Isneutral from Match
		- 20081223@PhuongNguyen: Get sdiscount, adiscount, discount, placing
		- 20081230@PhuongNguyen: Get livehomescore, liveawayscore, hdp1, hdp2 for Horse Racing
		- 20081231@PhuongNguyen: Remove placing
		- 20090109@PhuongNguyen: Get eventdate
		- 20090408@PhuongDao: Get checktime as SettleTime
		- 20090508@PhuongDao: Get username form bettrans and bettrans14 table
		- 20090509@Simon: Bet List For Casino
		- 20090528@PhuongDao: Add HR Fixed Odd
		- 20091002@Simon: Get Odds && OddsType columns
		- 20091003@Jamie: Remove comstatus out
		- 20091009@Daniel: Get refund status from bettrans
		- 20091015@Shifu: Get refno for Casino
		- 20091023@Simon: Displays Odds at Bet/Settle time
		- 20091205@Henry: Get more column: refno for viewing Mix Parlay detail
		- 20100306@Daniel: Query all @FromDate on winlostdate to support Finacial tickets
		- 20100409@Daniel: Support Mini game
		- 20100501@Daniel: Remove support Mini game
		- 20100524@Jamie: Show currency2's exchange rate for OpenTote
		- 20100603@Jamie: Change datatype transid to BIGINT
		- 20100611@Henry: Change mix-parlay match from 0 to 9
		- 20100907@Henry: Add IBC Bingo bettype
		- 20101007@Henry: Change column transid from INT to BIGINT
		- 20101130@Henry: Add column betid for number game
		- 20101201@Henry: Return winlost-actual_stake for column winlost
		- 20110408@Amy: Change function to get Odds value and odds type
		- 20110513@Lukas: re-arrange bettype
		- 20110705@Tom:Add new parameter @TransType and modify method get creator of the bet transaction
		- 20110711@Johnson: show exchange rate for SA Tote(Pool Currency)
		- 20110725@Lukas: Get refund tickets when transtype = 1
		- 20110802@Johnson: Add new bettype combination mix parlay
						- Add new column actual_stake for betlist
		- 20110810@Jamie: Get betteam for Combination Parlay
		- 20111122@Sophia: Add Checktime and SecAcceptFlag to show status waiting or running
		- 20111207@Sophia: Add P2P
		- 20120120@Sophia: Add Showtime for Table-hand-shoe of Live Casino
							Add sub detail for Live Casino
		- 20120405@Hurri: Exclude bettype 72 (P2P bet ticket) in the calculation of Casino
		- 20120416@Johnson: Correct column transid for p2p
		- 20120423@Lukas: show transid of main ticket for all subticket of system parlay
		- 20120528@Lukas: return refno for matchcode column (temporarily fix)
		- 20120606@Sophia: Change datatype of stake to money
		- 20120626@Elodie: exclude outright, HR from sportbook ( in case of matchid = orid)
		- 20120629@Sophia: Remove function f_GetOddsByBettype, f_ShowOddsByBettype,f_GetChoice for odds, Oddstype, betteam
		- 20120927@Johnson: get commstatus column to check double comm losing
		- 20130227@Elodie: Add Virtual HR product
		- 20130625@Elodie: Not apply Virtual HR for bet list by IP yet at this time
		- 20130718@Elodie: Apply core betlist
		- 20140306@Dom: Add Keno
		- 20140908@Dom: Update VS conditions [#Redmine 22012]
		- 20141103@Dom: Apply sport bettype matrix
		- 20152001@Dom: Fix Bug Virtual HR condition
		- 20150415@Sophia: Get Betcheck for Betradar
		- 20150506@Tom: Support Gold Deluxe Product [#34847]
		- 20150506@Bobby: Add transdesc column for metric gaming bettypes (801-899)
		- 20150615@Edward: Support for BetTrade
		- 20150707@Bobby: Exclude Metric Gaming running ticket from bettrans table
		- 20150708@Edward: Support for Microgaming Live Casino
		- 20150825@Kos: Add OddsSpread column to support Myanmar Odds
		- 20150828@Kos: Support Colossus Bet
		- 20150828@Kos: Fix bug not show CB ticket after clicking Grand Prize in Statement report
		- 20151009@Kos: Support Microgaming RNG Casino and AG Casino
		- 20151019@Kos: Support Microgaming RNG Casino Jackpot Win
		- 20151022@Kos: Return [translog].[transid3rd] and [bettransm].[betcheck] to support view CB ticket detail
		- 20151030@Kos: Change ProductId/SportType of Microgaming RNG Casino
		- 20151109@Kos: Replace using Jackpotwin table by PayoutTrans table
		- 20151119@Kos: Use PayoutTrans table in DBACC instead of DBAGE
		- 20151210@Kos: Change odds, modds data type from SMALLMONEY to MONEY [Redmine: #48660]
		- 20151214@Kos: Support Cockfighting (#Redmine: 48850)
		- 20151229@Kos: Support Colossus Bet ticket flow change [Redmine: #49967]
		- 20151229@Kos: Support RNG Casino Single Wallet [Redmine: #48958]
		- 20160121@Kos: Support PH All In One 1.2 [#Redmine: 50897]
		- 20160125@Kos: Fix Colossus Bet result issue
		- 20160129@Kos: Support RNG Casino Single Wallet yesterday running ticket
		- 20160215@Kos: Support AllBet [#Redmine: 50864]
		- 20160328@Kos: Support Grand Prize ticket which status is Expired
		- 20160331@Kos: Support Voidbridge [#Redmine: 54925]
		- 20160407@Kos: Support Combo Parlay [#Redmine: 55282]
		- 20160711@Kos: Change to use inline function for SportBettypeMatrix
		- 20160801@Kos: Fix bug not showing summary tickets if have only Void/Reject detail tickets [#Redmine: 61651]
		- 20160804@Kos: Exclude bet type 904 [#Redmine: 58978]
		- 20160810@Kos: Support NG2
		- 20161019@Kos: Remove Bingo and P2P in bettrans and bettrans14 range [#Redmine: 53988]
					- Support Fishing World [#Redmine: 65934]
		- 20170209@Kos: Statement - Unable to show NG2 betlist [#Redmine: 71344]
		- 20170228@Kos: Support KickOffTime for Virtual Soccer and Virtual Tennis [#Redmine: 71906]
		- 20170315@Kos: Support CashOut [#Redmine: 71963]
		- 20170602@Kos: Get liveindicator from original ticket for 911 and 912 tickets [#Redmine: 77669]
		- 20170616@Kos: Support Betradar Virtual Sports [#Redmine: 77280]
		- 20170629@Kos: Support Keno Lottery [#Redmine: 77929]
		- 20170718@Kos: Don't parse transdesc for Keno anymore [#Redmine: 80082]
		- 20170829@Kos: Support Lucky 3 [#Redmine: 75277]
		- 20171024@Kos: Support Bullfighting [#Redmine: 84961]
		- 20171227@Kos: Return ticket detail of Racing and Virtual Horse Racing [#Redmine: 88775]
					- Don't support Live Casino in bettrans and bettrans14 anymore
		- 20180118@Kos: Support Licensee Bonus System [#Redmine: 74978]
		- 20180305@Kos: Don't support Racing, Cockfighting, RNG Casino (bettype 71, 72) anymore [#Redmine: 86086]	
		- 20180323@Kos: Support ONERnG Jackpot [#Redmine: 88652]
		- 20180405@Kos: Support Pragmatic Casino [#Redmine: 92160]
		- 20180509@Kos: Support Keno 6 new Mini Games [#Redmine: 93759]
		- 20180515@Kos: Add Match No for Bullfighting [#Redmine: 84961]
		- 20180709@Kos: Support Poker Games [#Redmine: 97565]
		- 20180910@Kos: HotFix - Missing Seat # in Poker Games [#Redmine: 101215]
		- 20181003@Helen: Modify code to adapt indexes changed on DB053 [Redmine:101405]
		- 20181011@Kos: Support new status Result Pending and Under Settlement [#Redmine: 101949]
		- 20190107@Kos: Support Parlay Changes [#Redmine: 105585]
		- 20190503@Kos: Show match KO time for single ticket [#Redmine: 112092]
		- 20190611@Kos: Support Card Club [#Redmine: 107645]
					- Don't support Poker Games anymore
					- Remove param @Language, @TransId
		- 20190722@Kos: Support new status Pending [#Redmine: 113142]
		- 20190919@Kos: Hotfix - Wrong match showtime of Cash Out ticket [#Redmine: 120242]
		- 20190924@Kos: Don't support inactive products anymore [Redmine: #119100]
		- 20191029@Kos: Show Running status for Marked tickets [Redmine: 122391]
		- 20191105@Kos: Support Non-peak Hours Promotion [#Redmine: 121121]
		- 20191126@Kos: Support Spadegaming [Redmine: #122140]
		- 20191218@Kos: Support Virtual Games [Redmine: #124759]
		- 20200222@Kos: Support SA Gaming [Redmine: #128048]
		- 20200323@Kos: Support Indo 4D [Redmine: #130857]
		- 20200324@Kos: Support Sexy Gaming [Redmine: #130680]
		- 20200331@Kos: Support Saba.club [Redmine: #130769]
		- 20200402@Kos: Support Table Game [Redmine: #129433]
		- 20200502@Kos: Support Table Game Half Won Half Lose [Redmine: #133323]
		- 20200513@Kos: Support IBCBet Live Casino [Redmine: #130688]
		- 20200514@Kos: Support BBIN [Redmine: #131362]
		- 20200526@Kos: Support RNG War [Redmine: #132017]
		- 20200609@Kos: Support ION [Redmine: #132329]
		- 20200625@Kos: Integrate archive process for table VSRaceInfo [Redmine: #135963]
		- 20200709@Kos: Support PP Jackpot [Redmine: #137284]
		- 20200808@Kos: Support PG Soft [Redmine: #137769]
		- 20200919@Kos: Support Joker [Redmine: #137942]
		- 20201001@Kos: Support WM Live Casino [Redmine: #131588]
		- 20201123@Kos: Support God Of Fortune [Redmine: #145834]
		- 20201203@Kos: Support GDG [Redmine: #144104]
		- 20201217@Kos: Support Leap Gaming Virtual Sports 3 [Redmine: #131371]
		- 20201222@Kos: Support Big Gaming [Redmine: #142455]
		- 20201224@Razor: Support Happy 5 Linked Games [Redmine: #146540]
		- 20201231@Kos: Support MaxGame [Redmine: #147568]
		- 20210119@Kos: Support Saba.club Jackpot Contribution and Jackpot Prize tickets [Redmine: #147709]
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
		- 20211223@Razor: Support Third Party Result API [Redmine: #165815]
		- 20220209@Razor: Support TxId for 3rd products [Redmine: #167320]
		- 20220215@Razor: Support SG Jackpot [Redmine: #166683]
		- 20220317@Razor: Support FGG [Redmine: #165683]
		- 20220422@Razor: Support Virtual games result [Redmine: #170997]
		- 20220825@Razor: Support SEAL Entertainment [Redmine: #176210]
		- 20220909@Razor: Support Microgaming RNG Casino [Redmine: #175851]
		- 20221117@Razor: Support Player Tips [Redmine: #180590]
		- 20230206@Razor: Support Jili [Redmine: #182864]
		- 20230417@Razor: Remove Betfrom column [Redmine: #126137]
		- 20230526@Razor: Support YeeBet [Redmine: #186547]
		- 20230909@Razor: Remove GDG, Fishing World products [Redmine: #174511]
		- 20230909@Razor: Remove GD, Colossusbet products [Redmine: #179132]
		- 20231005@Kos: Support Parlay Boost [Redmine: #194992]
					- Don't support Cash Out bettype 911, 912, 913 anymore
		- 20231020@Razor: Support show max payout [Redmine: #194491]
		- 20231101@Razor: Return Device Type info [Redmine: #192667]
		- 20231108@Razor: Support WE Live Casino [Redmine: #195887]
		- 20231215@Razor: Support Live22 [Redmine: #197609]
		- 20240105@Razor: Extend data type [Redmine: #199259]
		- 20240222@Razor: Support Vitual Sports 4 [Redmine: #198619]
		- 20240327@Kos: Support UU Slots [Redmine: #192600]
		- 20240411@Razor: Return TranId3rd for Running ticket of Virtual Games/SportsLottery [Redmine: #203734]
		- 20240417@Razor: Support Saba xD [Redmine: #203371]
		- 20240419@Razor: Support Saba Coins [Redmine: #204003]
		- 20240626@Razor: Support FastSpin [Redmine: #205742]
		- 20240912@Razor: Support ON Casino [Redmine: #210026]
		- 20240920@Razor: Support VS2 Racing sports [Redmine: #211092]
		- 20241106@Razor: Support VS 5 - Virtually Sports [Redmine: #207589]
		- 20241210@Razor: Support VS6 - Betby Virtual Sports [Redmine: #212546]
		- 20250326@Benji: Support Upcoming Product (Microgaming Live Casino, Playtech Live Casino ) [Redmine: #221188]
		- 20250410@Benji: Remove Unnecessary Returned Data (VS7) [Redmine: #221188]
		- 20250414@Razor: Support Direct Member [Redmine: #211969]
		- 20250423@Dave: Change datatype for ExchangeID [RedmineID: #225169]
		- 20250730@Benji: Support Playtech RNG Jackpot - Support Automate Integration for Jackpot Betlist [Redmine: #234576]
		- 20250819@Razor: Support VS 2 - VS Tournament [Redmine: #235084]
		- 20250820@Benji: Support Playtech Live Jackpot [Redmine: #230127]
		- 20251027@Bobby: Support BetBuilder Hybrid Parlay [Redmine: #242255]


	Param's Explanation:
		+ @TransType:
			1: Betting Statement
			2: Void/Cancelled Bet
			3: Outstanding Bet
			4: Grand Prize (Colossus Bet)
*/

BEGIN
	SET NOCOUNT ON;

	-- Get Sport Bettype Matrix
	DECLARE @SportBettype TABLE(ProductID TINYINT, Bettype SMALLINT, EventType TINYINT, SubProduct VARCHAR(500), RefTable TINYINT)

	DECLARE @IsTest BIT = 0

	SELECT @IsTest = dbo.f_CheckSPVersion(@@PROCID)

	INSERT INTO @SportBettype (ProductID, Bettype, EventType, SubProduct, RefTable)
	SELECT ProductID, BetType, EventType, SubProduct, RefTable
	FROM dbo.f_SportBettypeMatrix_Sel (0, 0, 0, 2, '', '', @IsTest)
	WHERE Bettype NOT IN (904, 914)
		AND ProductID NOT IN (2, 4, 7, 9, 13, 17, 19, 24, 26, 30, 31, 33)
		AND (ProductID <> 6 OR SubProduct <> '')

	DECLARE @tmpStatus TABLE ([statusID] TINYINT);

	IF @TransType = 1
	BEGIN
		INSERT INTO @tmpStatus ([statusID])
		SELECT 111 UNION ALL
		SELECT 112 UNION ALL
		SELECT 113 UNION ALL
		SELECT 103
	END
	ELSE IF @TransType = 2
	BEGIN
		INSERT INTO @tmpStatus ([statusID])
		SELECT 101 UNION ALL
		SELECT 102
	END
	ELSE IF @TransType = 3
	BEGIN
		INSERT INTO @tmpStatus ([statusID])
		SELECT 0 UNION ALL
		SELECT 1
	END
	ELSE IF @TransType = 4	-- Grand Prize of ONERnG Jackpot
	BEGIN
		INSERT INTO @tmpStatus ([statusID])
		SELECT 111 UNION ALL
		SELECT 112 UNION ALL
		SELECT 113

		DELETE @SportBettype
		WHERE ProductID NOT IN (6)
	END

	DECLARE @Data TABLE (
		SportType			INT,
		LeagueId			INT,
		HomeId				INT,
		AwayId				INT,
		MatchCode			NVARCHAR(50),
		Race				NVARCHAR(50),
		EventDate			DATETIME,
		VirtualRate			FLOAT,			-- in case OpenToe, it's currency2's exchange rate 
		IsShowOTExRate		BIT,			-- Show OpenTote currency2's exchange rate or not 
		SDiscount			DECIMAL(9, 8),
		ADiscount			DECIMAL(9, 8),
		Discount			DECIMAL(9, 8),
		SettleTime			DATETIME,
		MatchId				INT,
		TransId				BIGINT,
		BetId				BIGINT,
		RefNo				BIGINT,
		TransDate			DATETIME,
		OddsId				INT,
		BetType				SMALLINT,
		Hdp1				SMALLMONEY,
		Hdp2				SMALLMONEY,
		Odds				MONEY,
		MOdds				MONEY,
		FinalOdds			MONEY,
		FinalOdds2			MONEY,
		OddsType			INT,
		BetTeam				NVARCHAR(50),
		Status				NVARCHAR(50),
		SettlementStatus	TINYINT,
		BetStatus			NVARCHAR(50),
		ComStatus			NVARCHAR(50),
		Stake				MONEY,
		Actual_Stake		MONEY,
		WinLost				MONEY,
		Commission			MONEY,
		LiveHomeScore		INT,
		LiveAwayScore		INT,
		LiveIndicator		BIT,
		FinalHomeScore		INT,
		FinalAwayScore		INT,
		HtHomeScore			INT,
		HtAwayScore			INT,
		Creator				VARCHAR(50),
		Ip					VARCHAR(45),
		Username			VARCHAR(50),
		IsNeutral			BIT,
		ShowTime			NVARCHAR(50),
		SPositionTaking		SMALLMONEY,
		MPositionTaking		SMALLMONEY,
		APositionTaking		SMALLMONEY,
		SPositionTaking2	SMALLMONEY,
		MPositionTaking2	SMALLMONEY,
		APositionTaking2	SMALLMONEY,
		SComm				MONEY,
		AComm				MONEY,
		Comm				MONEY,
		AWinLost			MONEY,
		MWinLost			MONEY,
		SWinLost			MONEY,
		WinLostDate			SMALLDATETIME,
		BetCheck			NVARCHAR(200),
		TransDesc			NVARCHAR(1000),
		OddsSpread			MONEY,
		OriginalBetType		INT,
		BetdaqId			BIGINT,
		ExtraInfo			VARCHAR(1000),
		WalletType			TINYINT,
		RefCode				BIGINT,
		CurrencyId			SMALLINT,
		SiteId				VARCHAR(20),
		DeviceType			TINYINT
	);

	IF @Fromdate <= @MoveBetsDay
	BEGIN
		IF @TransType <> 4
		BEGIN
			/* normal tickets
				- Sportsbook		: ProductID = 1
				- Number Game		: ProductID = 3
				- Virtual Sports	: ProductID = 5
				- Cash Out			: ProductID = 25
			*/
			INSERT INTO @Data (
				SportType, LeagueId, HomeId, AwayId, MatchCode, Race, EventDate, VirtualRate, IsShowOTExRate,
				SDiscount, ADiscount, Discount, SettleTime, MatchId, TransId, BetId, RefNo, TransDate, OddsId,
				BetType, Hdp1, Hdp2, Odds, MOdds, FinalOdds, FinalOdds2, OddsType, BetTeam, Status,
				SettlementStatus, BetStatus, ComStatus, Stake, Actual_Stake, WinLost, Commission,
				LiveHomeScore, LiveAwayScore, LiveIndicator, FinalHomeScore, FinalAwayScore, HtHomeScore, HtAwayScore,
				Creator, Ip, Username, IsNeutral, ShowTime, SPositionTaking, MPositionTaking, APositionTaking,
				SPositionTaking2, MPositionTaking2, APositionTaking2, SComm, AComm, Comm, AWinLost, MWinLost, SWinLost,
				WinLostDate, BetCheck, TransDesc, OddsSpread, OriginalBetType, BetdaqId, ExtraInfo, WalletType,
				RefCode, CurrencyId, SiteId, DeviceType
			)
			SELECT
				m.sporttype,
				m.leagueid,
				m.homeid,
				m.awayid,
				m.matchcode,
				'' AS race,
				CASE
					WHEN s.ProductID IN (1, 25) THEN m.GlobalShowTime
					ELSE m.eventdate
				END AS EventDate,
				0,
				0,
				b.sdiscount,
				CASE
					WHEN b.mrecommend = -4 THEN 0
					ELSE b.adiscount
				END,
				CASE
					WHEN b.recommend IN (-3, -4) THEN 0
					ELSE b.discount
				END,
				ISNULL(b.checktime, '') AS settletime,
				m.matchid,
				b.transid,
				ISNULL(b.BetID, 0),
				b.refno,
				b.transdate,
				b.oddsid,
				b.bettype,
				b.hdp1,
				b.hdp2,
				b.odds,
				b.modds,
				0 AS finalodds,
				0 AS finalodds2,
				b.oddstype,
				b.betteam,
				b.status,
				0 AS SettlementStatus,
				m.betstatus,
				CASE WHEN b.comstatus = '1' THEN 1 ELSE 0 END AS comstatus,
				b.stake,
				b.actual_stake,
				(b.winlost - b.actual_stake) AS WinLost,
				b.playercomm,
				b.livehomescore,
				b.liveawayscore,
				b.liveindicator,
				m.finalhomescore,
				m.finalawayscore,
				m.hthomescore,
				m.htawayscore,
				b.creator,
				b.ip,
				b.Username,
				ISNULL(m.IsNeutral, CONVERT(BIT, 0)) AS IsNeutral,
				CASE
					WHEN s.ProductID IN (5, 27) THEN CONVERT(NVARCHAR(50), m.kickofftime)
					ELSE m.showtime
				END AS ShowTime,
				0 spositiontaking, -- unuse in this report
				0 mpositiontaking, -- unuse in this report
				0 apositiontaking, -- unuse in this report
				0 spositiontaking2,-- unuse in this report
				0 mpositiontaking2,-- unuse in this report
				0 apositiontaking2,-- unuse in this report
				0 scomm, -- unuse in this report
				0 acomm, -- unuse in this report
				0 comm,	-- unuse in this report
				b.awinlost,
				b.mwinlost,
				b.swinlost,
				b.winlostdate,
				b.betcheck,
				ISNULL(b.transdesc, '') AS transdesc,
				ISNULL(b.oddsspread, 0) AS OddsSpread,
				0 AS OriginalBetType,
				CASE
					WHEN s.ProductID = 1 THEN ISNULL(b.betdaqid, -1)
					ELSE -1
				END AS BetdaqId,
				ISNULL(b.ExtraInfo, '') AS ExtraInfo,
				CASE
					WHEN s.ProductID = 1 THEN ISNULL(b.WalletType, 0)
					ELSE 0
				END AS WalletType,
				CASE
					WHEN s.ProductID = 1 THEN ISNULL(b.RefCode, 0)
					ELSE 0
				END AS RefCode,
				0 AS CurrencyId,
				'' AS SiteId,
				b.DeviceType
			FROM dbo.bettrans14 AS b WITH (NOLOCK)
				INNER JOIN @SportBettype AS s ON s.Bettype = b.bettype
				INNER JOIN dbo.match14 AS m WITH (NOLOCK) ON b.matchid = m.matchid
			WHERE b.custid = @CustId
				AND b.winlostdate = @FromDate
				AND s.EventType = 1
				AND b.statusID IN (SELECT statusID FROM @tmpStatus)

			-- VS 5
			UNION ALL
			SELECT
				m.sporttype,
				m.league3rdid,
				m.homeid,
				m.awayid,
				m.matchcode,
				'' AS race,
				'' AS EventDate,
				0,
				0,
				b.sdiscount,
				CASE
					WHEN b.mrecommend = -4 THEN 0
					ELSE b.adiscount
				END,
				CASE
					WHEN b.recommend IN (-3, -4) THEN 0
					ELSE b.discount
				END,
				ISNULL(b.checktime, '') AS settletime,
				m.match3rdid,
				b.transid,
				ISNULL(b.BetID, 0),
				b.refno,
				b.transdate,
				b.oddsid,
				b.bettype,
				b.hdp1,
				b.hdp2,
				b.odds,
				b.modds,
				0 AS finalodds,
				0 AS finalodds2,
				b.oddstype,
				b.betteam,
				b.status,
				0 AS SettlementStatus,
				m.betstatus,
				0 AS comstatus,
				b.stake,
				b.actual_stake,
				(b.winlost - b.actual_stake) AS WinLost,
				b.playercomm,
				b.livehomescore,
				b.liveawayscore,
				b.liveindicator,
				m.finalhomescore,
				m.finalawayscore,
				m.hthomescore,
				m.htawayscore,
				b.creator,
				b.ip,
				b.Username,
				CONVERT(BIT, 0) AS IsNeutral,
				'' AS ShowTime,
				0 spositiontaking, -- unuse in this report
				0 mpositiontaking, -- unuse in this report
				0 apositiontaking, -- unuse in this report
				0 spositiontaking2,-- unuse in this report
				0 mpositiontaking2,-- unuse in this report
				0 apositiontaking2,-- unuse in this report
				0 scomm, -- unuse in this report
				0 acomm, -- unuse in this report
				0 comm,	-- unuse in this report
				b.awinlost,
				b.mwinlost,
				b.swinlost,
				b.winlostdate,
				b.betcheck,
				ISNULL(b.transdesc, '') AS transdesc,
				ISNULL(b.oddsspread, 0) AS OddsSpread,
				0 AS OriginalBetType,
				-1 AS BetdaqId,
				ISNULL(b.ExtraInfo, '') AS ExtraInfo,
				0 AS WalletType,
				0 AS RefCode,
				0 AS CurrencyId,
				'' AS SiteId,
				b.DeviceType
			FROM dbo.bettrans14 AS b WITH (NOLOCK)
				INNER JOIN @SportBettype AS s ON s.Bettype = b.bettype
				INNER JOIN dbo.match3rd14 AS m WITH (NOLOCK) ON b.matchid = m.match3rdid
			WHERE b.custid = @CustId
				AND b.winlostdate = @FromDate
				AND s.EventType = 5
				AND b.statusID IN (SELECT statusID FROM @tmpStatus)

			-- Mix Parlay, System Parlay, Mix Parlay (Betradar Virtual Sports), Mix Parlay (VS4), Mix Parlay (VS5)
			UNION ALL
			SELECT
				0,
				0,
				0,
				0,
				'',
				'' AS race,
				'' AS eventdate,
				0,
				0,
				b.sdiscount,
				CASE
					WHEN b.mrecommend = -4 THEN 0
					ELSE b.adiscount
				END,
				CASE
					WHEN b.recommend IN (-3, -4) THEN 0
					ELSE b.discount
				END,
				ISNULL(b.checktime, '') AS settletime,
				0 AS MatchId,
				CASE
					WHEN b.bettype = 29 AND ISNULL(b.betid, 0) > 0 THEN b.betid
					ELSE b.transid
				END AS TransId,
				ISNULL(b.betid, 0),
				b.refno,
				b.transdate,
				0,
				b.bettype,
				b.hdp1,
				b.hdp2,
				b.odds,
				b.modds,
				0 AS finalodds,
				0 AS finalodds2,
				'' AS oddstype,
				b.betteam,
				b.status,
				0 AS SettlementStatus,
				'' AS betstatus,
				CASE WHEN b.comstatus = '1' THEN 1 ELSE 0 END AS comstatus,
				b.stake,
				b.actual_stake,
				(b.winlost - b.actual_stake) AS WinLost,
				b.playercomm,
				0,
				0,
				0,
				0,
				0,
				0,
				0,
				b.creator,
				b.ip,
				b.Username,
				CONVERT(BIT, 0) AS IsNeutral,
				'' AS showtime,
				0 spositiontaking, -- unuse in this report
				0 mpositiontaking, -- unuse in this report
				0 apositiontaking, -- unuse in this report
				0 spositiontaking2,-- unuse in this report
				0 mpositiontaking2,-- unuse in this report
				0 apositiontaking2,-- unuse in this report
				0 scomm, -- unuse in this report
				0 acomm, -- unuse in this report
				0 comm,	-- unuse in this report
				b.awinlost,
				b.mwinlost,
				b.swinlost,
				b.winlostdate,
				ISNULL(b.betcheck, '') AS BetCheck,
				IIF(b.bettype = 29 AND b.oddsspread = 3, ISNULL(b.transdesc, ''), '') AS transdesc,
				ISNULL(b.oddsspread, 0) AS OddsSpread,
				0 AS OriginalBetType,
				-1 AS BetdaqId,
				ISNULL(b.ExtraInfo, '') AS ExtraInfo,
				0 AS WalletType,
				0 AS RefCode,
				0 AS CurrencyId,
				'' AS SiteId,
				b.DeviceType
			FROM dbo.bettrans14 AS b WITH (NOLOCK)
			WHERE b.custid = @CustId
				AND b.winlostdate = @FromDate
				AND b.bettype IN (9, 29, 2798, 2799, 10449, 11099)
				AND b.statusID IN (SELECT [statusID] FROM @tmpStatus)

			-- Outright
			UNION ALL
			SELECT
				l.sporttype,
				o.leagueid,
				o.teamid,
				0,
				o.matchcode,
				o.groupmatch AS race,
				o.eventdate,
				b.virtualrate,
				CASE WHEN b.currency2 IS NULL THEN CONVERT(BIT,0) ELSE CONVERT(BIT,1) END AS isShowOTExRate,
				b.sdiscount,
				CASE
					WHEN b.mrecommend = -4 THEN 0
					ELSE b.adiscount
				END,
				CASE
					WHEN b.recommend IN (-3, -4) THEN 0
					ELSE b.discount
				END,
				ISNULL(b.checktime, '') AS settletime,
				'',
				b.transid,
				ISNULL(b.betid, 0),
				b.refno,
				b.transdate,
				o.orid,
				b.bettype,
				b.hdp1,
				b.hdp2,
				b.odds,
				b.modds,
				0 AS FinalOdds,
				0 AS FinalOdds2,
				b.oddstype AS oddstype,
				'',
				b.status,
				0 AS SettlementStatus,
				'',
				CASE WHEN b.comstatus = '1' THEN 1 ELSE 0 END AS comstatus,
				b.stake,
				b.actual_stake,
				(b.winlost - b.actual_stake) AS WinLost,
				b.playercomm,
				b.livehomescore,
				b.liveawayscore,
				0,
				0,
				0,
				0,
				0,
				b.creator,
				b.ip,
				b.Username,
				CONVERT(BIT, 0) AS IsNeutral,
				'' AS showtime,
				0 spositiontaking, -- unuse in this report
				0 mpositiontaking, -- unuse in this report
				0 apositiontaking, -- unuse in this report
				0 spositiontaking2,-- unuse in this report
				0 mpositiontaking2,-- unuse in this report
				0 apositiontaking2,-- unuse in this report
				0 scomm, -- unuse in this report
				0 acomm, -- unuse in this report
				0 comm,	-- unuse in this report
				b.awinlost,
				b.mwinlost,
				b.swinlost,
				b.winlostdate,
				b.BetCheck,
				'' AS transdesc,
				0 AS OddsSpread,
				0 AS OriginalBetType,
				-1 AS BetdaqId,
				'' AS ExtraInfo,
				0 AS WalletType,
				0 AS RefCode,
				0 AS CurrencyId,
				'' AS SiteId,
				b.DeviceType
			FROM dbo.bettrans14 AS b WITH (NOLOCK)
				INNER JOIN dbo.outright14 AS o WITH (NOLOCK) ON b.matchid = o.orid
				INNER JOIN dbo.league AS l WITH (NOLOCK) ON o.leagueid = l.leagueid
			WHERE b.custid = @CustId
				AND b.bettype = 10
				AND b.winlostdate = @FromDate
				AND b.statusID IN (SELECT [statusID] FROM @tmpStatus)

			-- Virtual Horse Racing, VS2 Racing
			UNION ALL
			SELECT
				r.SportType,
				r.LeagueID,
				0 AS homeid,
				0 AS awayid,
				'' AS matchcode,
				b.oddsid AS Race,
				'' AS EventDate,
				0,
				0,
				b.sdiscount,
				CASE
					WHEN b.mrecommend = -4 THEN 0
					ELSE b.adiscount
				END,
				CASE
					WHEN b.recommend IN (-3, -4) THEN 0
					ELSE b.discount
				END,
				ISNULL(b.checktime, '') AS settletime,
				b.matchid,
				b.transid,
				ISNULL(b.BetID, 0),
				b.refno,
				b.transdate,
				b.oddsid,
				b.bettype,
				b.hdp1,
				b.hdp2,
				b.odds,
				b.modds,
				0 AS finalodds,
				0 AS finalodds2,
				b.oddstype,
				b.betteam AS betteam,
				b.status,
				0 AS SettlementStatus,
				'' AS betstatus,
				CASE WHEN b.comstatus = '1' THEN 1 ELSE 0 END AS comstatus,
				b.stake,
				b.actual_stake,
				(b.winlost - b.actual_stake) AS WinLost,
				b.playercomm,
				b.livehomescore,
				b.liveawayscore,
				0 AS liveindicator,
				0 AS finalhomescore,
				0 AS finalawayscore,
				0 AS hthomescore,
				0 AS htawayscore,
				b.creator,
				b.ip,
				b.Username,
				CONVERT(BIT, 0) AS IsNeutral,
				'' AS ShowTime,
				0 spositiontaking, -- unuse in this report
				0 mpositiontaking, -- unuse in this report
				0 apositiontaking, -- unuse in this report
				0 spositiontaking2,-- unuse in this report
				0 mpositiontaking2,-- unuse in this report
				0 apositiontaking2,-- unuse in this report
				0 scomm, -- unuse in this report
				0 acomm, -- unuse in this report
				0 comm,	-- unuse in this report
				b.awinlost,
				b.mwinlost,
				b.swinlost,
				b.winlostdate,
				b.BetCheck,
				b.transdesc AS transdesc,
				0 AS OddsSpread,
				0 AS OriginalBetType,
				-1 AS BetdaqId,
				ISNULL(b.ExtraInfo, '') AS ExtraInfo,
				0 AS WalletType,
				0 AS RefCode,
				0 AS CurrencyId,
				'' AS SiteId,
				b.DeviceType
			FROM dbo.bettrans14 AS b WITH (NOLOCK)
				INNER JOIN dbo.VSRaceInfo14 AS r WITH (NOLOCK) ON r.EventID = b.matchid
				INNER JOIN @SportBettype AS s ON s.Bettype = b.bettype
			WHERE b.custid = @CustId
				AND b.winlostdate = @FromDate
				AND s.ProductID IN (5, 27, 106)
				AND s.EventType = 3
				AND b.statusID IN (SELECT statusID FROM @tmpStatus)

			-- RNG Casino, Keno, AG Casino, AllBet, Voidbridge, NG2, Lottery, Pragmatic Casino
			-- Card Club, NPH Promotion, Spadegaming, Virtual Games, SA Gaming, Indo 4D, Sexy Gaming, Saba.club, Table Game, BBIN
			-- IBCBet Live Casino, RNG War, ION, PG Soft, Joker, WM, Leap Gaming Virtual Sports, Big Gaming, Happy 5 Linked Games (Number Game)
			-- MaxGame, Habanero, CG, Sports Lottery, PP Live Casino, VGaming, AdvantPlay, AdvantPlay Mini, FGG, SEAL Entertainment, MG RNG Casino
			-- Player Tips, Jili, YeeBet, WE, Live22, UU Slots, Saba xD, Saba Coins
			UNION ALL
			SELECT
				CASE
					WHEN s.ProductID = 6 THEN b.matchid
					WHEN s.ProductID = 8 THEN 202
					WHEN s.ProductID = 11 THEN 250
					WHEN s.ProductID = 21 THEN 211
					WHEN s.ProductID = 22 THEN 212
					WHEN s.ProductID = 23 AND s.Bettype BETWEEN 2501 AND 2539 THEN 213
					WHEN s.ProductID = 23 AND s.Bettype BETWEEN 2541 AND 2579 THEN 214
					WHEN s.ProductID = 23 AND s.Bettype BETWEEN 2581 AND 2619 THEN 215
					WHEN s.ProductID = 23 AND s.Bettype BETWEEN 2621 AND 2659 THEN 216
					WHEN s.ProductID = 23 AND s.Bettype BETWEEN 2681 AND 2699 THEN 218
					WHEN s.ProductID = 28 THEN 220
					WHEN s.ProductID = 32 THEN 248
					WHEN s.ProductID IN (3, 34, 36, 37, 38, 39, 40, 42, 43, 45, 46, 47, 49, 50, 51, 52, 55, 56, 57, 60, 61, 62, 63, 65, 66, 67, 68, 70, 72, 73, 74, 75, 76, 78, 79, 80, 86, 81) THEN b.matchid
					WHEN s.RefTable IN (1, 2) THEN b.matchid
					ELSE 0
				END AS SportType,
				0 AS leagueid,
				0 AS homeid,
				0 AS awayid,
				'' AS matchcode,
				'' AS race,
				'' AS eventdate,
				0,
				0,
				b.sdiscount,
				CASE
					WHEN b.mrecommend = -4 THEN 0
					ELSE b.adiscount
				END,
				CASE
					WHEN b.recommend IN (-3, -4) THEN 0
					ELSE b.discount
				END,
				ISNULL(b.checktime, '') AS settletime,
				CASE
					WHEN s.ProductId = 23 THEN b.betdaqid
					WHEN s.ProductID = 74 THEN ISNULL(CAST(('<xml>' + b.ExtraInfo + '</xml>') AS XML).value('data(/xml/p74/@m)[1]','INT'), 0)
					ELSE 0
				END AS MatchID,
				b.transid,
				ISNULL(b.betid, 0),
				b.refno,
				b.transdate,
				b.oddsid,
				b.bettype,
				CASE
					WHEN s.ProductId = 23 THEN b.hdp1
					ELSE 0
				END AS hdp1,
				CASE
					WHEN s.ProductId = 23 THEN b.hdp2
					ELSE 0
				END AS hdp2,
				CASE 
					WHEN s.ProductID IN (3, 6, 8, 23, 28, 32, 36, 38, 40, 42, 43, 49, 63, 66) THEN b.Odds
					ELSE 0 
				END AS Odds,
				0 AS modds,
				0 AS finalodds,
				0 AS finalodds2,
				0 AS OddsType,
				'' AS betteam,
				CASE
					WHEN s.ProductID = 40 AND b.status = 'Won' AND b.modds = 0.25 THEN 'Half Won'
					WHEN s.ProductID = 40 AND b.status = 'Lose' AND b.modds = -0.25 THEN 'Half Lose'
					ELSE b.status
				END AS status,
				0 AS SettlementStatus,
				'' AS betstatus,
				'' AS comstatus,
				b.stake,
				b.actual_stake,
				(b.winlost - b.actual_stake) AS WinLost,
				b.playercomm,
				CASE
					WHEN s.ProductId = 23 THEN b.livehomescore
					ELSE 0
				END AS livehomescore,
				0 AS liveawayscore,
				0 AS liveindicator,
				0 AS finalhomescore,
				0 AS finalawayscore,
				0 AS hthomescore,
				0 AS htawayscore,
				b.creator,
				b.ip,
				b.Username,
				0 AS IsNeutral,
				'' AS showtime,
				0 AS spositiontaking, -- unuse in this report
				0 AS mpositiontaking, -- unuse in this report
				0 AS apositiontaking, -- unuse in this report
				0 AS spositiontaking2,-- unuse in this report
				0 AS mpositiontaking2,-- unuse in this report
				0 AS apositiontaking2,-- unuse in this report
				0 AS scomm, -- unuse in this report
				0 AS acomm, -- unuse in this report
				0 AS comm,	-- unuse in this report
				b.awinlost,
				b.mwinlost,
				b.swinlost,
				b.winlostdate,
				CASE
					WHEN s.ProductID IN (3, 38, 63) THEN b.betcheck
					WHEN s.ProductId = 8 THEN ISNULL(b.comstatus, '')
					ELSE ''
				END AS betcheck,
				CASE
					WHEN s.ProductId IN (3, 6, 8, 22, 23, 28, 32, 34, 36, 38, 40, 43, 49, 55, 56, 61, 62, 63, 67, 68, 72) THEN b.transdesc
					ELSE ''
				END AS transdesc,
				CASE
					WHEN s.SubProduct LIKE 'Jackpot%' THEN ISNULL(b.oddsspread, 0)		
					ELSE 0
				END AS OddsSpread,
				0 AS OriginalBetType,
				-1 AS BetdaqId,
				ISNULL(b.ExtraInfo, '') AS ExtraInfo,
				0 AS WalletType,
				0 AS RefCode,
				CASE
					WHEN s.ProductId IN (3, 63) THEn b.currency
					ELSE 0
				END AS CurrencyId,
				CASE
					WHEN s.ProductID IN (3, 38, 63) THEN CONVERT(VARCHAR(20), b.betdaqid)
					ELSE ''
				END AS SiteId,
				b.DeviceType
			FROM dbo.bettrans14 AS b WITH (NOLOCK)
				INNER JOIN @SportBettype AS s ON s.Bettype = b.bettype
			WHERE b.custid = @CustId
				AND b.winlostdate = @FromDate
				AND (s.ProductID IN (6, 8, 11, 21, 22, 23, 28, 32, 34, 36, 37, 38, 39, 40, 42, 43, 45, 46, 47, 49, 50, 51, 52, 55, 56, 57, 60, 61, 62, 63, 65, 66, 67, 68, 70, 72, 73, 74, 75, 76, 78, 79, 80, 86, 81)
						OR (s.ProductID = 3 AND s.EventType = 0)
						OR RefTable IN (1, 2))
				AND b.statusID IN (SELECT [statusID] FROM @tmpStatus)

			-- Bitcoin
			UNION ALL
			SELECT
				m.sporttype,
				CASE
					WHEN s.ProductID = 69 THEN 0 
					ELSE m.League3rdId
				END AS leagueid,
				CASE 
					WHEN s.ProductID = 69 THEN 0 
					ELSE m.HomeId
				END AS homeid,
				CASE
					WHEN s.ProductID = 69 THEN 0
					ELSE m.AwayId
				END AS awayid,
				''  matchcode,
				'' AS race,
				m.EndTime AS EventDate,
				0,
				0,
				b.sdiscount,
				CASE
					WHEN b.mrecommend = -4 THEN 0
					ELSE b.adiscount
				END,
				CASE
					WHEN b.recommend IN (-3, -4) THEN 0
					ELSE b.discount
				END,
				'' AS settletime,
				b.matchid,
				b.transid,
				CASE
					WHEN s.ProductId = 71 THEN b.BetID
					ELSE 0 
				END AS BetId,
				b.refno,
				b.transdate,
				0.oddsid,
				b.bettype,
				b.hdp1,
				CASE 
					WHEN s.ProductID = 69 THEN 0
					ELSE b.hdp2
				END AS hdp2,
				b.odds,
				0 modds,
				0 AS finalodds,
				0 AS finalodds2,
				b.oddstype,
				b.betteam,
				b.status,
				0 AS SettlementStatus,
				m.betstatus,
				0 AS comstatus,
				b.stake,
				b.actual_stake,
				(b.winlost - b.actual_stake) AS WinLost,
				b.playercomm,
				0 livehomescore,
				0 liveawayscore,
				CASE
					WHEN s.ProductID = 69 THEN 0
					ELSE b.liveindicator
				END AS liveindicator,
				0 finalhomescore,
				0 finalawayscore,
				0 hthomescore,
				0 htawayscore,
				b.creator,
				b.ip,
				b.Username,
				0 AS IsNeutral,
				CASE 
					WHEN s.ProductID = 71 THEN CONVERT(NVARCHAR(50), m.StartTime)
					ELSE '' 
				END AS ShowTime,
				b.spositiontaking,
				b.mpositiontaking,
				b.apositiontaking,
				0 spositiontaking2,
				0 mpositiontaking2,
				0 apositiontaking2,
				(b.scomm - b.acomm) AS scomm,
				(b.acomm - b.comm) AS acomm,
				(b.comm - b.playercomm) AS comm,
				b.awinlost,
				b.mwinlost,
				b.swinlost,
				b.winlostdate,
				'' betcheck,
				'' AS transdesc,
				0 AS OddsSpread,
				0 AS OriginalBetType,
				-1 AS BetdaqId,
				b.ExtraInfo,
				0 AS WalletType,
				0 AS RefCode,
				0 AS CurrencyId,
				'' AS SiteId,
				b.DeviceType
			FROM dbo.bettrans14 AS b WITH (NOLOCK)
				INNER JOIN @SportBettype AS s ON s.Bettype = b.bettype
				INNER JOIN dbo.match3rd14 AS m WITH (NOLOCK) ON b.matchid = m.match3rdid
			WHERE b.custid = @CustId
				AND b.winlostdate = @FromDate
				AND b.statusID IN (SELECT statusID FROM @tmpStatus);

			-- Get match info for Player Tips
			IF EXISTS (SELECT 1 FROM @Data WHERE SportType = 157)
			BEGIN
				UPDATE b
				SET
					LeagueId = m.leagueid,
					HomeId = m.homeid,
					AwayId = m.awayid,
					EventDate = m.GlobalShowTime
				FROM @Data AS b
					INNER JOIN dbo.match14 AS m WITH (NOLOCK) ON m.matchid = b.MatchId
				WHERE b.SportType = 157
			END
		END

		-- Grand Prize Jackpot Win
		IF @TransType = 4
		BEGIN
			-- ONERnG Jackpot
			INSERT INTO @Data (
				SportType, LeagueId, HomeId, AwayId, MatchCode, Race, EventDate, VirtualRate, IsShowOTExRate,
				SDiscount, ADiscount, Discount, SettleTime, MatchId, TransId, BetId, RefNo, TransDate, OddsId,
				BetType, Hdp1, Hdp2, Odds, MOdds, FinalOdds, FinalOdds2, OddsType, BetTeam, Status,
				SettlementStatus, BetStatus, ComStatus, Stake, Actual_Stake, WinLost, Commission,
				LiveHomeScore, LiveAwayScore, LiveIndicator, FinalHomeScore, FinalAwayScore, HtHomeScore, HtAwayScore,
				Creator, Ip, Username, IsNeutral, ShowTime, SPositionTaking, MPositionTaking, APositionTaking,
				SPositionTaking2, MPositionTaking2, APositionTaking2, SComm, AComm, Comm, AWinLost, MWinLost, SWinLost,
				WinLostDate, BetCheck, TransDesc, OddsSpread, OriginalBetType, BetdaqId, ExtraInfo, WalletType,
				RefCode, CurrencyId, SiteId, DeviceType
			)
			SELECT
				CASE
					WHEN s.ProductID = 6 THEN b.productID
					ELSE 0
				END AS SportType,
				0 AS leagueid,
				0 AS homeid,
				0 AS awayid,
				'' AS matchcode,
				'' AS race,
				'' AS eventdate,
				0,
				0,
				0 AS sdiscount,
				0 AS adiscount,
				0 AS discount,
				'' AS settletime,
				0 AS matchid,
				b.transid,
				0 AS BetId,
				b.RefNo,
				b.transdate,
				0 AS oddsid,
				b.gameID AS BetType,
				0 AS hdp1,
				0 AS hdp2,
				b.odds,
				0 AS modds,
				0 AS finalodds,
				0 AS finalodds2,
				0 AS oddstype,
				'' AS betteam,
				b.status,
				0 AS SettlementStatus,
				'' AS betstatus,
				0 AS comstatus,
				b.stake,
				b.actual_stake,
				CASE
					WHEN s.ProductID = 6 THEN (b.winlost - b.actual_stake)
					ELSE 0
				END AS WinLost,
				CASE
					WHEN s.ProductID = 6 THEN b.playercomm
					ELSE 0
				END AS PlayerComm,
				0 AS livehomescore,
				0 AS liveawayscore,
				0 AS liveindicator,
				0 AS finalhomescore,
				0 AS finalawayscore,
				0 AS hthomescore,
				0 AS htawayscore,
				b.creator,
				b.ip,
				b.Username,
				0 AS IsNeutral,
				'' AS showtime,
				0 AS spositiontaking, -- unuse in this report
				0 AS mpositiontaking, -- unuse in this report
				0 AS apositiontaking, -- unuse in this report
				0 AS spositiontaking2,-- unuse in this report
				0 AS mpositiontaking2,-- unuse in this report
				0 AS apositiontaking2,-- unuse in this report
				0 AS scomm, -- unuse in this report
				0 AS acomm, -- unuse in this report
				0 AS comm,	-- unuse in this report
				0 AS awinlost,
				0 AS mwinlost,
				0 AS swinlost,
				pt.winlostdate,
				b.TranId3rd AS BetCheck,
				b.transdesc,
				0 AS OddsSpread,
				0 AS OriginalBetType,
				CASE
					WHEN s.ProductID = 6 THEN ISNULL(b.RefNo2, -1)
					ELSE -1
				END AS BetdaqId,
				'' AS ExtraInfo,
				0 AS WalletType,
				0 AS RefCode,
				0 AS CurrencyId,
				'' AS SiteId,
				b.DeviceType
			FROM DBACC.bodb02.dbo.PayoutTrans AS pt WITH (NOLOCK)
				INNER JOIN dbo.bettransRnG14 AS b WITH (NOLOCK) ON pt.RefNo = b.transid
				INNER JOIN @SportBettype AS s ON s.Bettype = b.gameID
			WHERE pt.custid = @CustId
				AND pt.winlostdate = @FromDate
				AND (s.ProductID = 6 AND pt.PayoutStatus IN ('Completed', 'Expired'))
				AND b.statusID IN (SELECT [statusID] FROM @tmpStatus)

		END
	END
	ELSE
	BEGIN
		IF @TransType <> 4
		BEGIN
			/* normal tickets
				- Sportsbook		: ProductID = 1
				- Number Game		: ProductID = 3
				- Virtual Sports	: ProductID = 5
				- Cash Out			: ProductID = 25
			*/
			INSERT INTO @Data (
				SportType, LeagueId, HomeId, AwayId, MatchCode, Race, EventDate, VirtualRate, IsShowOTExRate,
				SDiscount, ADiscount, Discount, SettleTime, MatchId, TransId, BetId, RefNo, TransDate, OddsId,
				BetType, Hdp1, Hdp2, Odds, MOdds, FinalOdds, FinalOdds2, OddsType, BetTeam, Status,
				SettlementStatus, BetStatus, ComStatus, Stake, Actual_Stake, WinLost, Commission,
				LiveHomeScore, LiveAwayScore, LiveIndicator, FinalHomeScore, FinalAwayScore, HtHomeScore, HtAwayScore,
				Creator, Ip, Username, IsNeutral, ShowTime, SPositionTaking, MPositionTaking, APositionTaking,
				SPositionTaking2, MPositionTaking2, APositionTaking2, SComm, AComm, Comm, AWinLost, MWinLost, SWinLost,
				WinLostDate, BetCheck, TransDesc, OddsSpread, OriginalBetType, BetdaqId, ExtraInfo, WalletType,
				RefCode, CurrencyId, SiteId, DeviceType
			)
			SELECT
				m.sporttype,
				m.leagueid,
				m.homeid,
				m.awayid,
				m.matchcode,
				'' AS race,
				CASE
					WHEN s.ProductID IN (1, 25) THEN m.GlobalShowTime
					ELSE m.eventdate
				END AS EventDate,
				0,
				0,
				b.sdiscount,
				CASE
					WHEN b.mrecommend = -4 THEN 0
					ELSE b.adiscount
				END,
				CASE
					WHEN b.recommend IN (-3, -4) THEN 0
					ELSE b.discount
				END,
				ISNULL(b.checktime, '') AS settletime,
				m.matchid,
				b.transid,
				ISNULL(b.betid, 0),
				b.refno,
				b.transdate,
				b.oddsid,
				b.bettype,
				b.hdp1,
				b.hdp2,
				b.odds,
				b.modds,
				0 AS finalodds,
				0 AS finalodds2,
				b.oddstype,
				b.betteam,
				CASE
					WHEN b.status = 'running' AND ISNULL(b.SecAcceptFlag, 0) = 1 AND ISNULL(b.checktime, CURRENT_TIMESTAMP) > CURRENT_TIMESTAMP THEN 'waiting'
					ELSE b.status
				END AS status,
				ISNULL(m.SettlementStatus, 0) AS SettlementStatus,
				m.betstatus,
				CASE WHEN b.comstatus = '1' THEN 1 ELSE 0 END AS comstatus,
				b.stake,
				b.actual_stake,
				(b.winlost - b.actual_stake) AS WinLost,
				b.playercomm,
				b.livehomescore,
				b.liveawayscore,
				b.liveindicator,
				m.finalhomescore,
				m.finalawayscore,
				m.hthomescore,
				m.htawayscore,
				b.creator,
				b.ip,
				b.Username,
				ISNULL(m.isNeutral, CONVERT(BIT, 0)) AS IsNeutral, --phuong.nguyen, get isneutral from Match
				CASE
					WHEN s.ProductID IN (5, 27) THEN CONVERT(NVARCHAR(50), m.kickofftime)
					ELSE m.showtime
				END AS ShowTime,
				0 spositiontaking, -- unuse in this report
				0 mpositiontaking, -- unuse in this report
				0 apositiontaking, -- unuse in this report
				0 spositiontaking2,-- unuse in this report
				0 mpositiontaking2,-- unuse in this report
				0 apositiontaking2,-- unuse in this report
				0 scomm, -- unuse in this report
				0 acomm, -- unuse in this report
				0 comm,	-- unuse in this report
				b.awinlost,
				b.mwinlost,
				b.swinlost,
				b.winlostdate,
				b.BetCheck,
				ISNULL(b.transdesc, '') AS transdesc,
				ISNULL(b.oddsspread, 0) AS OddsSpread,
				0 AS OriginalBetType,
				CASE
					WHEN s.ProductID = 1 THEN ISNULL(b.betdaqid, -1)
					ELSE -1
				END AS BetdaqId,
				ISNULL(b.ExtraInfo, '') AS ExtraInfo,
			CASE
				WHEN s.ProductID = 1 THEN ISNULL(b.WalletType, 0)
				ELSE 0
			END AS WalletType,
			CASE
				WHEN s.ProductID = 1 THEN ISNULL(b.RefCode, 0)
				ELSE 0
			END AS RefCode,
			0 AS CurrencyId,
			'' AS SiteId,
			b.DeviceType
			FROM dbo.bettrans AS b WITH (NOLOCK)
				INNER JOIN @SportBettype AS s ON s.Bettype = b.bettype
				INNER JOIN dbo.match AS m WITH (NOLOCK) ON b.matchid = m.matchid
			WHERE b.custid = @CustId
				AND b.winlostdate = @FromDate
				AND s.EventType = 1
				AND b.statusID IN (SELECT [statusID] FROM @tmpStatus)
				AND (b.bettype NOT BETWEEN 801 AND 806			--exclude metric gaming running ticket
					OR (b.bettype BETWEEN 801 AND 806 AND b.statusID NOT IN (0, 1)))

			-- VS 5
			UNION ALL
			SELECT
				m.sporttype,
				m.league3rdid,
				m.homeid,
				m.awayid,
				m.matchcode,
				'' AS race,
				'' AS EventDate,
				0,
				0,
				bs5.sdiscount,
				CASE
					WHEN bs5.mrecommend = -4 THEN 0
					ELSE bs5.adiscount
				END,
				CASE
					WHEN bs5.recommend IN (-3, -4) THEN 0
					ELSE bs5.discount
				END,
				ISNULL(bs5.checktime, '') AS settletime,
				m.match3rdid,
				bs5.transid,
				ISNULL(bs5.betid, 0),
				bs5.refno,
				bs5.transdate,
				bs5.oddsid,
				bs5.bettype,
				bs5.hdp1,
				bs5.hdp2,
				bs5.odds,
				bs5.modds,
				0 AS finalodds,
				0 AS finalodds2,
				bs5.oddstype,
				bs5.betteam,
				bs5.status AS status,
				0 AS SettlementStatus,
				m.betstatus,
				0 AS comstatus,
				bs5.stake,
				bs5.actual_stake,
				(bs5.winlost - bs5.actual_stake) AS WinLost,
				bs5.playercomm,
				bs5.livehomescore,
				bs5.liveawayscore,
				bs5.liveindicator,
				m.finalhomescore,
				m.finalawayscore,
				m.hthomescore,
				m.htawayscore,
				bs5.creator,
				bs5.ip,
				bs5.Username,
				CONVERT(BIT, 0) AS IsNeutral, --phuong.nguyen, get isneutral from Match
				'' AS ShowTime,
				0 spositiontaking, -- unuse in this report
				0 mpositiontaking, -- unuse in this report
				0 apositiontaking, -- unuse in this report
				0 spositiontaking2,-- unuse in this report
				0 mpositiontaking2,-- unuse in this report
				0 apositiontaking2,-- unuse in this report
				0 scomm, -- unuse in this report
				0 acomm, -- unuse in this report
				0 comm,	-- unuse in this report
				bs5.awinlost,
				bs5.mwinlost,
				bs5.swinlost,
				bs5.winlostdate,
				bs5.BetCheck,
				ISNULL(bs5.transdesc, '') AS transdesc,
				ISNULL(bs5.oddsspread, 0) AS OddsSpread,
				0 AS OriginalBetType,
				-1 AS BetdaqId,
				ISNULL(bs5.ExtraInfo, '') AS ExtraInfo,
				0 AS WalletType,
				0 AS RefCode,
				0 AS CurrencyId,
				'' AS SiteId,
				bs5.DeviceType
			FROM dbo.bettrans AS bs5 WITH (NOLOCK)
				INNER JOIN @SportBettype AS s ON s.Bettype = bs5.bettype
				INNER JOIN dbo.match3rd AS m WITH (NOLOCK) ON bs5.matchid = m.match3rdid
			WHERE bs5.custid = @CustId
				AND bs5.winlostdate = @FromDate
				AND s.EventType = 5
				AND bs5.statusID IN (SELECT [statusID] FROM @tmpStatus)

			-- Metric gaming running ticket
			UNION ALL
			SELECT 
				m.sporttype,
				m.leagueid,
				m.homeid,
				m.awayid,
				m.matchcode,
				'' AS race,
				m.GlobalShowTime AS EventDate,
				0,
				0,
				tlm.sdiscount,
				CASE
					WHEN tlm.mrecommend = -4 THEN 0
					ELSE tlm.adiscount
				END,
				CASE
					WHEN tlm.recommend IN (-3, -4) THEN 0
					ELSE tlm.discount
				END,
				'' AS settletime,
				m.matchid,
				tlm.translogid AS transid,
				0 AS BetID,
				tlm.translogid AS refno,
				tlm.transdate,
				0 AS oddsid,
				tlm.gameID AS bettype,
				0 AS hdp1,
				0 AS hdp2,
				tlm.odds,
				0 AS modds,
				0 AS finalodds,
				0 AS finalodds2,
				CASE
					WHEN tlm.gameid IN (801, 803, 804, 805, 806) THEN CONVERT(TINYINT, ISNULL(tlm.custom1, 0))
					ELSE 0
				END AS OddsType,
				'' AS betteam,
				tlm.status,
				ISNULL(m.SettlementStatus, 0) AS SettlementStatus,
				m.betstatus,
				0 AS comstatus,
				tlm.stake,
				tlm.actual_stake,
				0 AS WinLost,
				0 AS playercomm,
				0 AS livehomescore,
				0 AS liveawayscore,
				0 AS liveindicator,
				m.finalhomescore,
				m.finalawayscore,
				m.hthomescore,
				m.htawayscore,
				tlm.creator,
				tlm.ip,
				tlm.Username,
				ISNULL(m.isNeutral, CONVERT(BIT, 0)) AS IsNeutral, --phuong.nguyen, get isneutral from Match
				m.showtime,
				0 spositiontaking, -- unuse in this report
				0 mpositiontaking, -- unuse in this report
				0 apositiontaking, -- unuse in this report
				0 spositiontaking2,-- unuse in this report
				0 mpositiontaking2,-- unuse in this report
				0 apositiontaking2,-- unuse in this report
				0 scomm, -- unuse in this report
				0 acomm, -- unuse in this report
				0 comm,	-- unuse in this report
				0 AS awinlost,
				0 AS mwinlost,
				0 AS swinlost,
				tlm.winlostdate,
				'' AS BetCheck,
				tlm.transdesc,
				0 AS OddsSpread,
				0 AS OriginalBetType,
				-1 AS BetdaqId,
				'' AS ExtraInfo,
				0 AS WalletType,
				0 AS RefCode,
				0 AS CurrencyId,
				'' AS SiteId,
				tlm.DeviceType
			FROM
				dbo.translog AS tlm WITH (NOLOCK)
				INNER JOIN dbo.custInfo AS c WITH (NOLOCK) ON c.custid = tlm.creator
				INNER JOIN dbo.match AS m WITH (NOLOCK) ON tlm.eventid = m.matchid
			WHERE tlm.custid = @CustId
				AND tlm.winlostdate = @FromDate
				AND tlm.gameID BETWEEN 801 AND 899
				AND tlm.statusID IN (0,1)
				AND tlm.statusID IN (SELECT [statusID] FROM @tmpStatus WHERE statusID IN (0, 1))

			-- Mix Parlay, System Parlay, Mix Parlay (Betradar Virtual Sports), Mix Parlay (VS4), Mix Parlay (VS5)
			UNION ALL
			SELECT 
				0,
				0,
				0,
				0,
				'',
				'' AS race,
				'' AS eventdate,
				0,
				0,
				bmx.sdiscount,
				CASE
					WHEN bmx.mrecommend = -4 THEN 0
					ELSE bmx.adiscount
				END,
				CASE
					WHEN bmx.recommend IN (-3, -4) THEN 0
					ELSE bmx.discount
				END,
				ISNULL(bmx.checktime, '') AS settletime,
				0 AS MatchId,
				CASE
					WHEN bmx.bettype = 29 AND ISNULL(bmx.betid, 0) > 0 THEN bmx.betid
					ELSE bmx.transid
				END AS TransId,
				ISNULL(bmx.betid, 0),
				bmx.refno,
				bmx.transdate,
				0,
				bmx.bettype,
				bmx.hdp1,
				bmx.hdp2,
				bmx.odds,
				bmx.modds,
				0 AS finalodds,
				0 AS finalodds2,
				'' AS oddstype,
				bmx.betteam,
				CASE
					WHEN bmx.status = 'running' THEN
						CASE
							WHEN EXISTS (SELECT 1 FROM dbo.bettransm AS bm WITH (NOLOCK)
										WHERE bm.custid = bmx.custid
											AND bm.refno = bmx.refno
											AND (bm.status = 'waiting'
												OR (bm.status = 'running' AND ISNULL(bm.SecAcceptFlag, 0) = 1 AND ISNULL(bm.checktime, CURRENT_TIMESTAMP) > CURRENT_TIMESTAMP)))
								THEN 'Waiting'
							ELSE bmx.status
						END
					ELSE bmx.status
				END AS Status,
				0 AS SettlementStatus,
				'' AS betstatus,
				CASE WHEN bmx.comstatus = '1' THEN 1 ELSE 0 END AS comstatus,
				bmx.stake,
				bmx.actual_stake,
				(bmx.winlost - bmx.actual_stake) AS WinLost,
				bmx.playercomm,
				0,
				0,
				0,
				0,
				0,
				0,
				0,
				bmx.creator,
				bmx.ip,
				bmx.Username,
				CONVERT(BIT, 0) AS IsNeutral,
				'' AS showtime,
				0 spositiontaking, -- unuse in this report
				0 mpositiontaking, -- unuse in this report
				0 apositiontaking, -- unuse in this report
				0 spositiontaking2,-- unuse in this report
				0 mpositiontaking2,-- unuse in this report
				0 apositiontaking2,-- unuse in this report
				0 scomm, -- unuse in this report
				0 acomm, -- unuse in this report
				0 comm,	-- unuse in this report
				bmx.awinlost,
				bmx.mwinlost,
				bmx.swinlost,
				bmx.winlostdate,
					ISNULL(bmx.betcheck, '') AS BetCheck,
				IIF(bmx.bettype = 29 AND bmx.oddsspread = 3, ISNULL(bmx.transdesc, ''), '') AS transdesc,
				ISNULL(bmx.oddsspread, 0) AS OddsSpread,
				0 AS OriginalBetType,
				-1 AS BetdaqId,
				ISNULL(bmx.ExtraInfo, '') AS ExtraInfo,
				0 AS WalletType,
				0 AS RefCode,
				0 AS CurrencyId,
				'' AS SiteId,
				bmx.DeviceType
			FROM dbo.bettrans AS bmx WITH (NOLOCK)
			WHERE bmx.custid = @CustId
				AND bmx.winlostdate = @FromDate
				AND bmx.bettype IN (9, 29, 2798, 2799, 10449, 11099)
				AND bmx.statusID IN (SELECT [statusID] FROM @tmpStatus)

			-- Outright
			UNION ALL
			SELECT 
				l.sporttype,
				o.leagueid,
				o.teamid,
				0,
				o.matchcode,
				o.groupmatch AS race,
				o.eventdate,
				bor.virtualrate,
				CASE WHEN bor.currency2 IS NULL THEN CONVERT(BIT,0) ELSE CONVERT(BIT,1) END AS isShowOTExRate,
				bor.sdiscount,
				CASE
					WHEN bor.mrecommend = -4 THEN 0
					ELSE bor.adiscount
				END,
				CASE
					WHEN bor.recommend IN (-3, -4) THEN 0
					ELSE bor.discount
				END,
				'' AS settletime,
				'',
				bor.transid,
				ISNULL(bor.betid, 0),
				bor.refno,
				bor.transdate,
				o.orid,
				bor.bettype,
				bor.hdp1,
				bor.hdp2,
				bor.odds,
				bor.modds,
				0 AS FinalOdds,
				0 AS FinalOdds2,
				bor.oddstype AS oddstype,
				'',
				bor.status,
				0 AS SettlementStatus,
				'',
				CASE WHEN bor.comstatus = '1' THEN 1 ELSE 0 END AS comstatus,
				bor.stake,
				bor.actual_stake,
				(bor.winlost - bor.actual_stake) AS WinLost,
				bor.playercomm,
				bor.livehomescore,
				bor.liveawayscore,
				0,
				0,
				0,
				0,
				0,
				bor.creator,
				bor.ip,
				bor.Username,
				CONVERT(BIT, 0) AS IsNeutral,
				'' AS showtime,
				0 spositiontaking, -- unuse in this report
				0 mpositiontaking, -- unuse in this report
				0 apositiontaking, -- unuse in this report
				0 spositiontaking2,-- unuse in this report
				0 mpositiontaking2,-- unuse in this report
				0 apositiontaking2,-- unuse in this report
				0 scomm, -- unuse in this report
				0 acomm, -- unuse in this report
				0 comm,	-- unuse in this report
				bor.awinlost,
				bor.mwinlost,
				bor.swinlost,
				bor.winlostdate,
				bor.BetCheck,
				'' AS transdesc,
				0 AS OddsSpread,
				0 AS OriginalBetType,
				-1 AS BetdaqId,
				'' AS ExtraInfo,
				0 AS WalletType,
				0 AS RefCode,
				0 AS CurrencyId,
				'' AS SiteId,
				bor.DeviceType
			FROM dbo.bettrans AS bor WITH (NOLOCK)
				INNER JOIN dbo.outright AS o WITH (NOLOCK) ON bor.matchid = o.orid
				INNER JOIN dbo.league AS l WITH (NOLOCK) ON o.leagueid = l.leagueid
			WHERE bor.custid = @CustId
				AND bor.bettype = 10
				AND bor.winlostdate = @FromDate
				AND bor.statusID IN (SELECT [statusID] FROM @tmpStatus)

			-- Virtual Horse Racing, VS2 Racing
			UNION ALL
			SELECT 
				r.SportType,
				r.LeagueID,
				0 AS homeid,
				0 AS awayid,
				'' AS matchcode,
				bvr.oddsid AS Race,
				'' AS EventDate,
				0,
				0,
				bvr.sdiscount,
				CASE
					WHEN bvr.mrecommend = -4 THEN 0
					ELSE bvr.adiscount
				END,
				CASE
					WHEN bvr.recommend IN (-3, -4) THEN 0
					ELSE bvr.discount
				END,
				ISNULL(bvr.checktime, '') AS settletime,
				bvr.matchid,
				bvr.transid,
				ISNULL(bvr.BetID, 0),
				bvr.refno,
				bvr.transdate,
				bvr.oddsid,
				bvr.bettype,
				bvr.hdp1,
				bvr.hdp2,
				bvr.odds,
				bvr.modds,
				0 AS finalodds,
				0 AS finalodds2,
				bvr.oddstype,
				bvr.betteam AS betteam,
				bvr.status,
				0 AS SettlementStatus,
				'' AS betstatus,
				CASE WHEN bvr.comstatus = '1' THEN 1 ELSE 0 END AS comstatus,
				bvr.stake,
				bvr.actual_stake,
				(bvr.winlost - bvr.actual_stake) AS WinLost,
				bvr.playercomm,
				bvr.livehomescore,
				bvr.liveawayscore,
				0 AS liveindicator,
				0 AS finalhomescore,
				0 AS finalawayscore,
				0 AS hthomescore,
				0 AS htawayscore,
				bvr.creator,
				bvr.ip,
				bvr.Username,
				CONVERT(BIT, 0) AS IsNeutral,
				'' AS ShowTime,
				0 spositiontaking, -- unuse in this report
				0 mpositiontaking, -- unuse in this report
				0 apositiontaking, -- unuse in this report
				0 spositiontaking2,-- unuse in this report
				0 mpositiontaking2,-- unuse in this report
				0 apositiontaking2,-- unuse in this report
				0 scomm, -- unuse in this report
				0 acomm, -- unuse in this report
				0 comm,	-- unuse in this report
				bvr.awinlost,
				bvr.mwinlost,
				bvr.swinlost,
				bvr.winlostdate,
				bvr.BetCheck,
				bvr.transdesc AS transdesc,
				0 AS OddsSpread,
				0 AS OriginalBetType,
				-1 AS BetdaqId,
				ISNULL(bvr.ExtraInfo, '') AS ExtraInfo,
				0 AS WalletType,
				0 AS RefCode,
				0 AS CurrencyId,
				'' AS SiteId,
				bvr.DeviceType
			FROM dbo.bettrans AS bvr WITH (NOLOCK)
				INNER JOIN dbo.VSRaceInfo AS r WITH (NOLOCK) ON r.EventID = bvr.matchid
				INNER JOIN @SportBettype AS s ON s.Bettype = bvr.bettype
			WHERE bvr.custid = @CustId
				AND bvr.winlostdate = @FromDate
				AND s.EventType = 3
				AND bvr.statusID IN (SELECT statusID FROM @tmpStatus)

			-- NG2, BBIN
			UNION ALL
			SELECT
				CASE
					WHEN s.ProductID = 23 AND s.Bettype BETWEEN 2501 AND 2539 THEN 213
					WHEN s.ProductID = 23 AND s.Bettype BETWEEN 2541 AND 2579 THEN 214
					WHEN s.ProductID = 23 AND s.Bettype BETWEEN 2581 AND 2619 THEN 215
					WHEN s.ProductID = 23 AND s.Bettype BETWEEN 2621 AND 2659 THEN 216
					WHEN s.ProductID = 23 AND s.Bettype BETWEEN 2681 AND 2699 THEN 218
					WHEN s.ProductID IN (47) THEN bnb.matchid
					ELSE 0
				END AS SportType,
				0 AS leagueid,
				0 AS homeid,
				0 AS awayid,
				'' AS matchcode,
				'' AS race,
				'' AS eventdate,
				0,
				0,
				bnb.sdiscount,
				CASE
					WHEN bnb.mrecommend = -4 THEN 0
					ELSE bnb.adiscount
				END,
				CASE
					WHEN bnb.recommend IN (-3, -4) THEN 0
					ELSE bnb.discount
				END,
				'' AS settletime,
				CASE
					WHEN s.ProductId = 23 THEN bnb.betdaqid
					ELSE 0
				END AS matchid,
				bnb.transid,
				ISNULL(bnb.betid, 0),
				bnb.refno,
				bnb.transdate,
				bnb.oddsid,
				bnb.bettype,
				CASE
					WHEN s.ProductId = 23 THEN bnb.hdp1
					ELSE 0
				END AS hdp1,
				CASE
					WHEN s.ProductId = 23 THEN bnb.hdp2
					ELSE 0
				END AS hdp2,
				bnb.odds,
				0 AS modds,
				0 AS finalodds,
				0 AS finalodds2,
				0 AS oddstype,
				bnb.betteam,
				bnb.status,
				0 AS SettlementStatus,
				'' AS betstatus,
				'' AS comstatus,
				bnb.stake,
				bnb.actual_stake,
				(bnb.winlost - bnb.actual_stake) AS WinLost,
				bnb.playercomm,
				CASE
					WHEN s.ProductId = 23 THEN bnb.livehomescore
					ELSE 0
				END AS livehomescore,
				0 AS liveawayscore,
				0 AS liveindicator,
				0, --finalhomescore, 
				0, --finalawayscore, 
				0, --hthomescore, 
				0, --htawayscore,
				bnb.creator,
				bnb.ip,
				bnb.Username,
				0 AS IsNeutral,
				'' AS showtime,
				0 AS spositiontaking, -- unuse in this report
				0 AS mpositiontaking, -- unuse in this report
				0 AS apositiontaking, -- unuse in this report
				0 AS spositiontaking2,-- unuse in this report
				0 AS mpositiontaking2,-- unuse in this report
				0 AS apositiontaking2,-- unuse in this report
				0 AS scomm, -- unuse in this report
				0 AS acomm, -- unuse in this report
				0 AS comm,	-- unuse in this report
				bnb.awinlost,
				bnb.mwinlost,
				bnb.swinlost,
				bnb.winlostdate,
				'' AS BetCheck,
				CASE
					WHEN s.ProductId = 23 THEN ISNULL(bnb.transdesc, '')
					ELSE ''
				END AS transdesc,
				0 AS OddsSpread,
				0 AS OriginalBetType,
				-1 AS BetdaqId,
				'' AS ExtraInfo,
				0 AS WalletType,
				0 AS RefCode,
				0 AS CurrencyId,
				'' AS SiteId,
				bnb.DeviceType
			FROM dbo.bettrans AS bnb WITH (NOLOCK)
				INNER JOIN @SportBettype AS s ON s.Bettype = bnb.bettype
			WHERE bnb.custid = @CustId
				AND bnb.winlostdate = @FromDate
				AND s.ProductId IN (23, 47)
				AND bnb.statusID IN (SELECT [statusID] FROM @tmpStatus);

			-- Keno, Lottery, Virtual Games, Table Games, Indo 4D, Leap Gaming Virtual Sports, Happy 5 Linked Games(Number Game), Sports Lottery (translog)
			IF EXISTS (SELECT TOP(1) 1 FROM @tmpStatus WHERE statusID IN (0, 1))
			BEGIN
				INSERT INTO @Data (
					SportType, LeagueId, HomeId, AwayId, MatchCode, Race, EventDate, VirtualRate, IsShowOTExRate,
					SDiscount, ADiscount, Discount, SettleTime, MatchId, TransId, BetId, RefNo, TransDate, OddsId,
					BetType, Hdp1, Hdp2, Odds, MOdds, FinalOdds, FinalOdds2, OddsType, BetTeam, Status,
					SettlementStatus, BetStatus, ComStatus, Stake, Actual_Stake, WinLost, Commission,
					LiveHomeScore, LiveAwayScore, LiveIndicator, FinalHomeScore, FinalAwayScore, HtHomeScore, HtAwayScore,
					Creator, Ip, Username, IsNeutral, ShowTime, SPositionTaking, MPositionTaking, APositionTaking,
					SPositionTaking2, MPositionTaking2, APositionTaking2, SComm, AComm, Comm, AWinLost, MWinLost, SWinLost,
					WinLostDate, BetCheck, TransDesc, OddsSpread, OriginalBetType, BetdaqId, ExtraInfo, WalletType,
					RefCode, CurrencyId, SiteId, DeviceType
				)
				SELECT 
					CASE
						WHEN s.ProductId = 8 THEN 202
						WHEN s.ProductID = 28 THEN 220
						WHEN s.ProductID IN (3, 38, 40, 43, 49, 63) THEN btl.productID
						ELSE 0
					END AS sporttype,
					0 AS leagueid,
					0 AS homeid,
					0 AS awayid,
					'' AS matchcode,
					'' AS race,
					'' AS eventdate,
					0,
					0,
					btl.sdiscount,
					CASE
						WHEN btl.mrecommend = -4 THEN 0
						ELSE btl.adiscount
					END,
					CASE
						WHEN btl.recommend IN (-3, -4) THEN 0
						ELSE btl.discount
					END,
					'' AS settletime,
					0 AS MatchId,
					0 AS transid,
					0 AS betid,
					btl.translogid AS refno,
					btl.transdate,
					0 AS oddsid,
					btl.gameID AS bettype,
					0 AS hdp1,
					0 AS hdp2,
					CASE
						WHEN s.ProductId IN (3, 8, 28, 38, 40, 43, 49, 63) THEN btl.odds
						ELSE 0
					END AS odds,
					0 AS modds,
					0 AS finalodds,
					0 AS finalodds2,
					0 AS OddsType,
					'' AS betteam,
					btl.status,
					0 AS SettlementStatus,
					'' AS betstatus,
					0 AS comstatus,
					btl.stake,
					btl.actual_stake,
					0 AS WinLost,
					0 AS playercomm,
					0 AS livehomescore,
					0 AS liveawayscore,
					0 AS liveindicator,
					0 AS finalhomescore,
					0 AS finalawayscore,
					0 AS hthomescore,
					0 AS htawayscore,
					btl.creator,
					btl.ip,
					btl.Username,
					0 AS IsNeutral,
					'' AS showtime,
					0 AS spositiontaking, -- unuse in this report
					0 AS mpositiontaking, -- unuse in this report
					0 AS apositiontaking, -- unuse in this report
					0 AS spositiontaking2,-- unuse in this report
					0 AS mpositiontaking2,-- unuse in this report
					0 AS apositiontaking2,-- unuse in this report
					0 AS scomm, -- unuse in this report
					0 AS acomm, -- unuse in this report
					0 AS comm,	-- unuse in this report
					0 AS awinlost,
					0 AS mwinlost,
					0 AS swinlost,
					btl.winlostdate,
					CASE
						WHEN s.ProductId IN (3) THEN btl.GameID3rd
						WHEN s.ProductId IN (38, 63) THEN btl.TranId3rd
						WHEN s.ProductId = 8 THEN ISNULL(btl.custom2, '')
						WHEN s.ProductId = 49 THEN ISNULL(btl.custom1, '')
						ELSE ''
					END AS BetCheck,
					CASE
						WHEN s.ProductId IN (3, 8, 28, 38, 40, 43, 49, 63) THEN btl.transdesc
						ELSE ''
					END AS transdesc,
					0 AS OddsSpread,
					0 AS OriginalBetType,
					-1 AS BetdaqId,
					'' AS ExtraInfo,
					0 AS WalletType,
					0 AS RefCode,
					CASE
						WHEN s.ProductId IN (3, 63) THEN btl.currency
						ELSE 0
					END AS CurrencyId,
					CASE
						WHEN s.ProductId IN (3, 38, 63) THEN btl.SiteId
						ELSE ''
					END AS SiteId,
					btl.DeviceType
				FROM dbo.translog AS btl WITH (NOLOCK)
					INNER JOIN @SportBettype AS s ON s.Bettype = btl.gameID
				WHERE btl.custid = @CustId
					AND btl.winlostdate = @FromDate
					AND (s.ProductID IN (8, 28, 38, 40, 43, 49, 63)
							OR (s.ProductID = 3 AND s.EventType = 0))
					AND btl.statusID IN (0, 1)
			END

			-- Keno, Lottery, NPH Promotion, Virtual Games, Table Games, Indo 4D, Leap Gaming Virtual Sports, Happy 5 Linked Games(Number Game), Sports Lottery, Player Tips, Saba Coins (bettrans)
			IF EXISTS (SELECT TOP(1) 1 FROM @tmpStatus WHERE statusID NOT IN (0, 1))
			BEGIN
				INSERT INTO @Data (
					SportType, LeagueId, HomeId, AwayId, MatchCode, Race, EventDate, VirtualRate, IsShowOTExRate,
					SDiscount, ADiscount, Discount, SettleTime, MatchId, TransId, BetId, RefNo, TransDate, OddsId,
					BetType, Hdp1, Hdp2, Odds, MOdds, FinalOdds, FinalOdds2, OddsType, BetTeam, Status,
					SettlementStatus, BetStatus, ComStatus, Stake, Actual_Stake, WinLost, Commission,
					LiveHomeScore, LiveAwayScore, LiveIndicator, FinalHomeScore, FinalAwayScore, HtHomeScore, HtAwayScore,
					Creator, Ip, Username, IsNeutral, ShowTime, SPositionTaking, MPositionTaking, APositionTaking,
					SPositionTaking2, MPositionTaking2, APositionTaking2, SComm, AComm, Comm, AWinLost, MWinLost, SWinLost,
					WinLostDate, BetCheck, TransDesc, OddsSpread, OriginalBetType, BetdaqId, ExtraInfo, WalletType,
					RefCode, CurrencyId, SiteId, DeviceType
				)
				SELECT
					CASE
						WHEN s.ProductId = 8 THEN 202
						WHEN s.ProductID = 28 THEN 220
						WHEN s.ProductID IN (3, 37, 38, 40, 43, 49, 63, 74, 81) THEN bkl.matchid
						ELSE 0
					END AS sporttype,
					0 AS leagueid,
					0 AS homeid,
					0 AS awayid,
					'' AS matchcode,
					'' AS race,
					'' AS eventdate,
					0,
					0,
					bkl.sdiscount,
					CASE
						WHEN bkl.recommend IN (-3, -4) THEN 0
						ELSE bkl.adiscount
					END,
					CASE
						WHEN bkl.mrecommend = -4 THEN 0
						ELSE bkl.discount
					END,
					'' AS settletime,
					CASE
						WHEN s.ProductId = 74 THEN ISNULL(CAST(('<xml>' + bkl.ExtraInfo + '</xml>') AS XML).value('data(/xml/p74/@m)[1]','INT'), 0)
						ELSE 0
					END AS matchid,
					bkl.transid,
					ISNULL(bkl.BetID, 0) AS betid,
					bkl.refno,
					bkl.transdate,
					0 AS oddsid,
					bkl.bettype,
					0 AS hdp1,
					0 AS hdp2,
					CASE
						WHEN s.ProductId IN (3, 8, 28, 38, 40, 43, 49, 63) THEN bkl.odds
						ELSE 0
					END AS odds,
					0 AS modds,
					0 AS finalodds,
					0 AS finalodds2,
					0 AS OddsType,
					'' AS betteam,
					CASE
						WHEN s.ProductID = 40 AND bkl.status = 'Won' AND bkl.modds = 0.25 THEN 'Half Won'
						WHEN s.ProductID = 40 AND bkl.status = 'Lose' AND bkl.modds = -0.25 THEN 'Half Lose'
						ELSE bkl.status
					END AS status,
					0 AS SettlementStatus,
					'' AS betstatus,
					CASE WHEN bkl.comstatus = '1' THEN 1 ELSE 0 END AS comstatus,
					bkl.stake,
					bkl.actual_stake,
					(bkl.winlost - bkl.actual_stake) AS WinLost,
					bkl.playercomm,
					bkl.livehomescore,
					bkl.liveawayscore,
					bkl.liveindicator,
					0 AS finalhomescore,
					0 AS finalawayscore,
					0 AS hthomescore,
					0 AS htawayscore,
					bkl.creator,
					bkl.ip,
					bkl.Username,
					0 AS IsNeutral,
					'' AS showtime,
					0 AS spositiontaking, -- unuse in this report
					0 AS mpositiontaking, -- unuse in this report
					0 AS apositiontaking, -- unuse in this report
					0 AS spositiontaking2,-- unuse in this report
					0 AS mpositiontaking2,-- unuse in this report
					0 AS apositiontaking2,-- unuse in this report
					0 AS scomm, -- unuse in this report
					0 AS acomm, -- unuse in this report
					0 AS comm,	-- unuse in this report
					bkl.awinlost,
					bkl.mwinlost,
					bkl.swinlost,
					bkl.winlostdate,
					CASE
						WHEN s.ProductId IN (3, 28, 38, 63) THEN bkl.betcheck
						WHEN s.ProductId = 8 THEN ISNULL(bkl.comstatus, '')
						ELSE ''
					END AS BetCheck,
					CASE
						WHEN s.ProductId IN (3, 8, 28, 38, 40, 43, 49, 63) THEN bkl.transdesc
						ELSE ''
					END AS transdesc,
					0 AS OddsSpread,
					0 AS OriginalBetType,
					-1 AS BetdaqId,
					ISNULL(bkl.ExtraInfo, '') AS ExtraInfo,
					0 AS WalletType,
					0 AS RefCode,
					CASE
						WHEN s.ProductId IN (3, 63) THEN bkl.currency
						ELSE 0
					END AS CurrencyId,
					CASE
						WHEN s.ProductId IN (3, 38, 63) THEN CONVERT(VARCHAR(20), bkl.betdaqid)
						ELSE ''
					END AS SiteId,
					bkl.DeviceType
				FROM dbo.bettrans AS bkl WITH (NOLOCK)
					INNER JOIN @SportBettype AS s ON s.Bettype = bkl.bettype
				WHERE  bkl.custid = @CustId
					AND bkl.winlostdate = @FromDate
					AND (s.ProductID IN (8, 28, 37, 38, 40, 43, 49, 63, 74, 81)
							OR (s.ProductID = 3 AND s.EventType = 0))
					AND bkl.statusID IN (SELECT [statusID] FROM @tmpStatus)

				-- Get match info for Player Tips
				IF EXISTS (SELECT 1 FROM @Data WHERE SportType = 157)
				BEGIN
					UPDATE b
					SET
						LeagueId = m.leagueid,
						HomeId = m.homeid,
						AwayId = m.awayid,
						EventDate = m.GlobalShowTime
					FROM @Data AS b
						INNER JOIN dbo.match AS m WITH (NOLOCK) ON m.matchid = b.MatchId
					WHERE b.SportType = 157
				END

			END

			-- RNG Casino Single Wallet, Voidbridge, Pragmatic Casino, Card Club, Spadegaming, Saba.club, RNG War, PG Soft, Joker, MaxGame, Habanero, CG, VGaming
			-- AdvantPlay, AdvantPlay Mini, SEAL Entertainment, MG RNG Casino, Jili, Live22, UU Slots, Saba xD
			IF @TransType = 1	-- before yesterday settled ticket
				AND @FromDate < DATEADD(DAY, DATEDIFF(DAY, 1, GETDATE()), 0)
			BEGIN
				INSERT INTO @Data (
					SportType, LeagueId, HomeId, AwayId, MatchCode, Race, EventDate, VirtualRate, IsShowOTExRate,
					SDiscount, ADiscount, Discount, SettleTime, MatchId, TransId, BetId, RefNo, TransDate, OddsId,
					BetType, Hdp1, Hdp2, Odds, MOdds, FinalOdds, FinalOdds2, OddsType, BetTeam, Status,
					SettlementStatus, BetStatus, ComStatus, Stake, Actual_Stake, WinLost, Commission,
					LiveHomeScore, LiveAwayScore, LiveIndicator, FinalHomeScore, FinalAwayScore, HtHomeScore, HtAwayScore,
					Creator, Ip, Username, IsNeutral, ShowTime, SPositionTaking, MPositionTaking, APositionTaking,
					SPositionTaking2, MPositionTaking2, APositionTaking2, SComm, AComm, Comm, AWinLost, MWinLost, SWinLost,
					WinLostDate, BetCheck, TransDesc, OddsSpread, OriginalBetType, BetdaqId, ExtraInfo, WalletType,
					RefCode, CurrencyId, SiteId, DeviceType
				)
				SELECT
					CASE
						WHEN s.ProductID = 22 THEN 212
						WHEN s.ProductID = 32 THEN 248
						ELSE br1.matchid
					END AS Sporttype,
					0 AS leagueid,
					0 AS homeid,
					0 AS awayid,
					'' AS matchcode,
					'' AS race,
					'' AS eventdate,
					0,
					0,
					br1.sdiscount,
					CASE
						WHEN br1.mrecommend = -4 THEN 0
						ELSE br1.adiscount
					END,
					CASE
						WHEN br1.recommend IN (-3, -4) THEN 0
						ELSE br1.discount
					END,
					'' AS settletime,
					0 AS matchid,
					br1.transid,
					ISNULL(br1.betid, 0) AS betid,
					br1.refno,
					br1.transdate,
					0 AS oddsid,
					br1.bettype,
					0 AS hdp1,
					0 AS hdp2,
					CASE
						WHEN s.SubProduct LIKE 'Jackpot%' THEN br1.odds
						ELSE 0
					END AS Odds,
					0 AS modds,
					0 AS finalodds,
					0 AS finalodds2,
					0 AS oddstype,
					'' AS betteam,
					br1.status,
					0 AS SettlementStatus,
					'' AS betstatus,
					CASE WHEN br1.comstatus = '1' THEN 1 ELSE 0 END AS comstatus,
					br1.stake,
					br1.actual_stake,
					(br1.winlost - br1.actual_stake) AS WinLost,
					br1.playercomm AS commission,
					0 AS livehomescore,
					0 AS liveawayscore,
					0 AS liveindicator,
					0 AS finalhomescore,
					0 AS finalawayscore,
					0 AS hthomescore,
					0 AS htawayscore,
					br1.creator,
					br1.ip,
					br1.Username,
					0 AS IsNeutral,
					'' AS showtime,
					0 AS spositiontaking, -- unuse in this report
					0 AS mpositiontaking, -- unuse in this report
					0 AS apositiontaking, -- unuse in this report
					0 AS spositiontaking2,-- unuse in this report
					0 AS mpositiontaking2,-- unuse in this report
					0 AS apositiontaking2,-- unuse in this report
					0 AS scomm, -- unuse in this report
					0 AS acomm, -- unuse in this report
					0 AS comm,	-- unuse in this report
					br1.awinlost,
					br1.mwinlost,
					br1.swinlost,
					br1.winlostdate,
					'' AS BetCheck,
					CASE
						WHEN s.ProductID IN (6, 22, 32, 34, 36, 55, 56, 61, 62, 67, 68, 72) THEN br1.transdesc
						ELSE ''
					END AS transdesc,
					CASE
						WHEN s.SubProduct LIKE 'Jackpot%' THEN ISNULL(br1.oddsspread, 0)
						ELSE 0
					END AS OddsSpread,
					0 AS OriginalBetType,
					-1 AS BetdaqId,
					'' AS ExtraInfo,
					0 AS WalletType,
					0 AS RefCode,
					0 AS CurrencyId,
					'' AS SiteId,
					br1.DeviceType
				FROM dbo.bettrans AS br1 WITH (NOLOCK)
					INNER JOIN @SportBettype AS s ON s.Bettype = br1.bettype
				WHERE br1.custid = @CustId
					AND br1.winlostdate = @FromDate
					AND (s.ProductId IN (6, 22, 32, 34, 36, 42, 50, 55, 56, 60, 61, 62, 66, 67, 68, 72, 73, 75, 78, 79, 86)
							OR s.RefTable = 1)
					AND br1.statusID IN (SELECT [statusID] FROM @tmpStatus)
			END

			IF @TransType = 1	-- yesterday and today settled ticket
				AND @FromDate BETWEEN DATEADD(DAY, DATEDIFF(DAY, 1, GETDATE()), 0)
					AND DATEADD(DAY, DATEDIFF(DAY, 0, GETDATE()), 0)
			BEGIN
				INSERT INTO @Data (
					SportType, LeagueId, HomeId, AwayId, MatchCode, Race, EventDate, VirtualRate, IsShowOTExRate,
					SDiscount, ADiscount, Discount, SettleTime, MatchId, TransId, BetId, RefNo, TransDate, OddsId,
					BetType, Hdp1, Hdp2, Odds, MOdds, FinalOdds, FinalOdds2, OddsType, BetTeam, Status,
					SettlementStatus, BetStatus, ComStatus, Stake, Actual_Stake, WinLost, Commission,
					LiveHomeScore, LiveAwayScore, LiveIndicator, FinalHomeScore, FinalAwayScore, HtHomeScore, HtAwayScore,
					Creator, Ip, Username, IsNeutral, ShowTime, SPositionTaking, MPositionTaking, APositionTaking,
					SPositionTaking2, MPositionTaking2, APositionTaking2, SComm, AComm, Comm, AWinLost, MWinLost, SWinLost,
					WinLostDate, BetCheck, TransDesc, OddsSpread, OriginalBetType, BetdaqId, ExtraInfo, WalletType,
					RefCode, CurrencyId, SiteId, DeviceType
				)
				SELECT
					CASE
						WHEN s.ProductID = 22 THEN 212
						WHEN s.ProductID = 32 THEN 248
						ELSE byt.matchid
					END AS Sporttype,
					0 AS leagueid,
					0 AS homeid,
					0 AS awayid,
					'' AS matchcode,
					'' AS race,
					'' AS eventdate,
					0,
					0,
					AVG(brng.sdiscount) AS sdiscount,
					CASE
						WHEN brng.mrecommend = -4 THEN 0
						ELSE AVG(brng.adiscount) 
					END AS adiscount,
					CASE
						WHEN brng.recommend IN (-3, -4) THEN 0
						ELSE AVG(brng.discount) 
					END AS discount,
					'' AS settletime,
					0 AS matchid,
					byt.transid,
					ISNULL(byt.betid, 0) AS betid,
					byt.refno,
					byt.transdate,
					0 AS oddsid,
					byt.bettype,
					0 AS hdp1,
					0 AS hdp2,
					CASE
						WHEN s.SubProduct LIKE 'Jackpot%'
							THEN ISNULL(AVG(CASE WHEN brng.statusID IN (111, 112, 113) THEN brng.ContributionRate END), 0)
						ELSE 0
					END AS Odds,
					0 AS modds,
					0 AS finalodds,
					0 AS finalodds2,
					0 AS oddstype,
					'' AS betteam,
					CASE 
						WHEN SUM(brng.winlost - brng.actual_stake) > 0 THEN 'Won'
						WHEN SUM(brng.winlost - brng.actual_stake) < 0 THEN 'Lose'
						ELSE 'Draw'
					END AS Status,
					0 AS SettlementStatus,
					'' AS betstatus,
					CASE WHEN byt.comstatus = '1' THEN 1 ELSE 0 END AS comstatus,
					SUM(brng.stake) AS stake,
					SUM(brng.actual_stake) AS actual_stake,
					SUM(brng.winlost - brng.actual_stake) AS WinLost,
					SUM(brng.playercomm) AS commission,
					0 AS livehomescore,
					0 AS liveawayscore,
					0 AS liveindicator,
					0 AS finalhomescore,
					0 AS finalawayscore,
					0 AS hthomescore,
					0 AS htawayscore,
					byt.creator,
					byt.ip,
					byt.Username,
					0 AS IsNeutral,
					'' AS showtime,
					0 AS spositiontaking, -- unuse in this report
					0 AS mpositiontaking, -- unuse in this report
					0 AS apositiontaking, -- unuse in this report
					0 AS spositiontaking2,-- unuse in this report
					0 AS mpositiontaking2,-- unuse in this report
					0 AS apositiontaking2,-- unuse in this report
					0 AS scomm, -- unuse in this report
					0 AS acomm, -- unuse in this report
					0 AS comm,	-- unuse in this report
					SUM(brng.awinlost) AS awinlost,
					SUM(brng.mwinlost) AS mwinlost,
					SUM(brng.swinlost) AS swinlost,
					byt.winlostdate,
					'' AS BetCheck,
					CASE
						WHEN s.ProductID IN (6, 22, 32, 34, 36, 55, 56, 61, 62, 67, 68, 72) THEN byt.transdesc
						ELSE ''
					END AS transdesc,
					CASE
						WHEN s.SubProduct LIKE 'Jackpot%' THEN ISNULL(SUM(brng.BetStake), 0)
						ELSE 0
					END AS OddsSpread,
					0 AS OriginalBetType,
					-1 AS BetdaqId,
					'' AS ExtraInfo,
					0 AS WalletType,
					0 AS RefCode,
					0 AS CurrencyId,
					'' AS SiteId,
					byt.DeviceType
				FROM dbo.bettrans AS byt WITH (NOLOCK)
					INNER JOIN dbo.bettransRnG AS brng WITH (NOLOCK) ON brng.RefNo = byt.transid
					INNER JOIN @SportBettype AS s ON s.Bettype = byt.bettype
				WHERE byt.custid = @CustId
					AND byt.winlostdate = @FromDate
					AND (s.ProductId IN (6, 22, 32, 34, 36, 42, 50, 55, 56, 60, 61, 62, 66, 67, 68, 72, 73, 75, 78, 79, 86)
							OR s.RefTable = 1)
					AND brng.statusID NOT IN (0, 1)
				GROUP BY
					byt.transid,
					s.SubProduct,
					ISNULL(byt.betid, 0),
					byt.bettype,
					byt.refno,
					byt.transdate,
					byt.winlostdate,
					byt.custid,
					byt.creator,
					byt.ip,
					byt.Username,
					byt.comstatus,
					byt.matchid,
					byt.transdesc,
					s.ProductID,
					byt.DeviceType,
					brng.recommend,
					brng.mrecommend
				OPTION (RECOMPILE)
			END

			IF EXISTS (SELECT TOP(1) 1 FROM @tmpStatus WHERE [statusID] IN (0, 1))	-- yesterday and later running ticket
				AND @FromDate >= DATEADD(DAY, DATEDIFF(DAY, 1, GETDATE()), 0)
			BEGIN
				INSERT INTO @Data (
					SportType, LeagueId, HomeId, AwayId, MatchCode, Race, EventDate, VirtualRate, IsShowOTExRate,
					SDiscount, ADiscount, Discount, SettleTime, MatchId, TransId, BetId, RefNo, TransDate, OddsId,
					BetType, Hdp1, Hdp2, Odds, MOdds, FinalOdds, FinalOdds2, OddsType, BetTeam, Status,
					SettlementStatus, BetStatus, ComStatus, Stake, Actual_Stake, WinLost, Commission,
					LiveHomeScore, LiveAwayScore, LiveIndicator, FinalHomeScore, FinalAwayScore, HtHomeScore, HtAwayScore,
					Creator, Ip, Username, IsNeutral, ShowTime, SPositionTaking, MPositionTaking, APositionTaking,
					SPositionTaking2, MPositionTaking2, APositionTaking2, SComm, AComm, Comm, AWinLost, MWinLost, SWinLost,
					WinLostDate, BetCheck, TransDesc, OddsSpread, OriginalBetType, BetdaqId, ExtraInfo, WalletType,
					RefCode, CurrencyId, SiteId, DeviceType
				)
				SELECT
					CASE
						WHEN s.ProductID = 22 THEN 212
						WHEN s.ProductID = 32 THEN 248
						ELSE brn.matchid
					END AS Sporttype,
					0 AS leagueid,
					0 AS homeid,
					0 AS awayid,
					'' AS matchcode,
					'' AS race,
					'' AS eventdate,
					0,
					0,
					AVG(brng.sdiscount) AS sdiscount,
					CASE
						WHEN brng.mrecommend = -4 THEN 0
						ELSE AVG(brng.adiscount) 
					END AS adiscount,
					CASE
						WHEN brng.recommend IN (-3, -4) THEN 0
						ELSE AVG(brng.discount) 
					END AS discount,
					'' AS settletime,
					0 AS matchid,
					brn.transid,
					ISNULL(brn.betid, 0) AS betid,
					brn.refno,
					brn.transdate,
					0 AS oddsid,
					brn.bettype,
					0 AS hdp1,
					0 AS hdp2,
					0 AS odds,
					0 AS modds,
					0 AS finalodds,
					0 AS finalodds2,
					0 AS oddstype,
					'' AS betteam,
					'Running' AS Status,
					0 AS SettlementStatus,
					'' AS betstatus,
					CASE WHEN brn.comstatus = '1' THEN 1 ELSE 0 END AS comstatus,
					SUM(brng.stake) AS stake,
					SUM(brng.actual_stake) AS actual_stake,
					0 AS WinLost,
					0 AS commission,
					0 AS livehomescore,
					0 AS liveawayscore,
					0 AS liveindicator,
					0 AS finalhomescore,
					0 AS finalawayscore,
					0 AS hthomescore,
					0 AS htawayscore,
					brn.creator,
					brn.ip,
					brn.Username,
					0 AS IsNeutral,
					'' AS showtime,
					0 AS spositiontaking, -- unuse in this report
					0 AS mpositiontaking, -- unuse in this report
					0 AS apositiontaking, -- unuse in this report
					0 AS spositiontaking2,-- unuse in this report
					0 AS mpositiontaking2,-- unuse in this report
					0 AS apositiontaking2,-- unuse in this report
					0 AS scomm, -- unuse in this report
					0 AS acomm, -- unuse in this report
					0 AS comm,	-- unuse in this report
					0 AS awinlost,
					0 AS mwinlost,
					0 AS swinlost,
					brn.winlostdate,
					'' AS BetCheck,
					CASE
						WHEN s.ProductID IN (6, 22, 32, 34, 36, 55, 56, 61, 62, 67, 68, 72) THEN brn.transdesc
						ELSE ''
					END AS transdesc,
					0 AS OddsSpread,
					0 AS OriginalBetType,
					-1 AS BetdaqId,
					'' AS ExtraInfo,
					0 AS WalletType,
					0 AS RefCode,
					0 AS CurrencyId,
					'' AS SiteId,
					brn.DeviceType
				FROM dbo.bettrans AS brn WITH (NOLOCK)
					INNER JOIN dbo.bettransRnG AS brng WITH (NOLOCK) ON brng.RefNo = brn.transid
					INNER JOIN @SportBettype AS s ON s.Bettype = brn.bettype
				WHERE brn.custid = @CustId
					AND brn.winlostdate = @FromDate
					AND (s.ProductId IN (6, 22, 32, 34, 36, 42, 50, 55, 56, 60, 61, 62, 66, 67, 68, 72, 73, 75, 78, 79, 86)
							OR s.RefTable = 1)
					AND brng.statusID IN (0, 1)
				GROUP BY
					brn.transid,
					ISNULL(brn.betid, 0),
					brn.Bettype,
					brn.refno,
					brn.transdate,
					brn.winlostdate,
					brn.custid,
					brn.creator,
					brn.ip,
					brn.Username,
					brn.comstatus,
					brn.matchid,
					brn.transdesc,
					s.ProductID,
					brn.DeviceType,
					brng.recommend,
					brng.mrecommend
				OPTION (RECOMPILE)
			END

			-- AG Casino, AllBet, SA Gaming, Sexy Gaming, IBCBet Live Casino, ION, WM, Big Gaming, PP Live Casino, FGG, YeeBet, WE
			IF @TransType = 1	-- before yesterday settled ticket
				AND @FromDate < DATEADD(DAY, DATEDIFF(DAY, 1, GETDATE()), 0)
			BEGIN
				INSERT INTO @Data (
					SportType, LeagueId, HomeId, AwayId, MatchCode, Race, EventDate, VirtualRate, IsShowOTExRate,
					SDiscount, ADiscount, Discount, SettleTime, MatchId, TransId, BetId, RefNo, TransDate, OddsId,
					BetType, Hdp1, Hdp2, Odds, MOdds, FinalOdds, FinalOdds2, OddsType, BetTeam, Status,
					SettlementStatus, BetStatus, ComStatus, Stake, Actual_Stake, WinLost, Commission,
					LiveHomeScore, LiveAwayScore, LiveIndicator, FinalHomeScore, FinalAwayScore, HtHomeScore, HtAwayScore,
					Creator, Ip, Username, IsNeutral, ShowTime, SPositionTaking, MPositionTaking, APositionTaking,
					SPositionTaking2, MPositionTaking2, APositionTaking2, SComm, AComm, Comm, AWinLost, MWinLost, SWinLost,
					WinLostDate, BetCheck, TransDesc, OddsSpread, OriginalBetType, BetdaqId, ExtraInfo, WalletType,
					RefCode, CurrencyId, SiteId, DeviceType
				)
				SELECT
					CASE
						WHEN s.ProductID = 11 THEN 250
						WHEN s.ProductID = 21 THEN 211
						WHEN s.ProductID IN (39, 45, 46, 51, 52, 57, 65, 70, 76, 80) THEN bby.matchid
						WHEN s.RefTable = 2 THEN bby.matchid
						ELSE 0
					END AS Sporttype,
					0 AS leagueid,
					0 AS homeid,
					0 AS awayid,
					'' AS matchcode,
					'' AS race,
					'' AS eventdate,
					0,
					0,
					bby.sdiscount,
					CASE
						WHEN bby.mrecommend = -4 THEN 0
						ELSE bby.adiscount
					END,
					CASE
						WHEN bby.recommend IN (-3, -4) THEN 0
						ELSE bby.discount
					END,
					'' AS settletime,
					0 AS matchid,
					bby.transid,
					ISNULL(bby.betid, 0) AS betid,
					bby.refno,
					bby.transdate,
					0 AS oddsid,
					bby.bettype,
					0 AS hdp1,
					0 AS hdp2,
					0 AS odds,
					0 AS modds,
					0 AS finalodds,
					0 AS finalodds2,
					0 AS oddstype,
					'' AS betteam,
					bby.status,
					0 AS SettlementStatus,
					'' AS betstatus,
					CASE WHEN bby.comstatus = '1' THEN 1 ELSE 0 END AS comstatus,
					bby.stake,
					bby.actual_stake,
					(bby.winlost - bby.actual_stake) AS WinLost,
					bby.playercomm AS commission,
					0 AS livehomescore,
					0 AS liveawayscore,
					0 AS liveindicator,
					0 AS finalhomescore,
					0 AS finalawayscore,
					0 AS hthomescore,
					0 AS htawayscore,
					bby.creator,
					bby.ip,
					bby.Username,
					0 AS IsNeutral,
					'' AS showtime,
					0 AS spositiontaking, -- unuse in this report
					0 AS mpositiontaking, -- unuse in this report
					0 AS apositiontaking, -- unuse in this report
					0 AS spositiontaking2,-- unuse in this report
					0 AS mpositiontaking2,-- unuse in this report
					0 AS apositiontaking2,-- unuse in this report
					0 AS scomm, -- unuse in this report
					0 AS acomm, -- unuse in this report
					0 AS comm,	-- unuse in this report
					bby.awinlost,
					bby.mwinlost,
					bby.swinlost,
					bby.winlostdate,
					'' AS BetCheck,
					'' AS transdesc,
					CASE 
						WHEN s.SubProduct LIKE 'Jackpot%' THEN ISNULL(bby.OddsSpread, 0)
						ELSE 0
					END	
					AS OddsSpread,
					0 AS OriginalBetType,
					-1 AS BetdaqId,
					'' AS ExtraInfo,
					0 AS WalletType,
					0 AS RefCode,
					0 AS CurrencyId,
					'' AS SiteId,
					bby.DeviceType
				FROM dbo.bettrans AS bby WITH (NOLOCK)
					INNER JOIN @SportBettype AS s ON s.Bettype = bby.bettype
				WHERE bby.custid = @CustId
					AND bby.winlostdate = @FromDate
					AND (s.ProductID IN (11, 21, 39, 45, 46, 51, 52, 57, 65, 70, 76, 80) OR s.RefTable = 2)
					AND bby.statusID IN (SELECT [statusID] FROM @tmpStatus)
			END

			IF @TransType = 1	-- yesterday and today settled ticket
				AND @FromDate BETWEEN DATEADD(DAY, DATEDIFF(DAY, 1, GETDATE()), 0)
					AND DATEADD(DAY, DATEDIFF(DAY, 0, GETDATE()), 0)
			BEGIN
				INSERT INTO @Data (
					SportType, LeagueId, HomeId, AwayId, MatchCode, Race, EventDate, VirtualRate, IsShowOTExRate,
					SDiscount, ADiscount, Discount, SettleTime, MatchId, TransId, BetId, RefNo, TransDate, OddsId,
					BetType, Hdp1, Hdp2, Odds, MOdds, FinalOdds, FinalOdds2, OddsType, BetTeam, Status,
					SettlementStatus, BetStatus, ComStatus, Stake, Actual_Stake, WinLost, Commission,
					LiveHomeScore, LiveAwayScore, LiveIndicator, FinalHomeScore, FinalAwayScore, HtHomeScore, HtAwayScore,
					Creator, Ip, Username, IsNeutral, ShowTime, SPositionTaking, MPositionTaking, APositionTaking,
					SPositionTaking2, MPositionTaking2, APositionTaking2, SComm, AComm, Comm, AWinLost, MWinLost, SWinLost,
					WinLostDate, BetCheck, TransDesc, OddsSpread, OriginalBetType, BetdaqId, ExtraInfo, WalletType,
					RefCode, CurrencyId, SiteId, DeviceType
				)
				SELECT
					CASE
						WHEN s.ProductID = 11 THEN 250
						WHEN s.ProductID = 21 THEN 211
						ELSE bcy.matchid
					END AS Sporttype,
					0 AS leagueid,
					0 AS homeid,
					0 AS awayid,
					'' AS matchcode,
					'' AS race,
					'' AS eventdate,
					0,
					0,
					AVG(blc.sdiscount) AS sdiscount,
					CASE
						WHEN blc.mrecommend = -4 THEN 0
						ELSE AVG(blc.adiscount) 
					END AS adiscount,
					CASE
						WHEN blc.recommend IN (-3, -4) THEN 0
						ELSE AVG(blc.discount) 
					END AS discount,
					'' AS settletime,
					0 AS matchid,
					bcy.transid,
					ISNULL(bcy.BetID, 0) AS betid,
					bcy.refno,
					bcy.transdate,
					0 AS oddsid,
					bcy.bettype,
					0 AS hdp1,
					0 AS hdp2,
					CASE
						WHEN s.SubProduct LIKE 'Jackpot%'
							THEN ISNULL(AVG(CASE WHEN blc.statusID IN (111, 112, 113) THEN blc.ContributionRate END), 0)
						ELSE 0
					END AS Odds,
					0 AS modds,
					0 AS finalodds,
					0 AS finalodds2,
					0 AS oddstype,
					'' AS betteam,
					CASE 
						WHEN SUM(blc.winlost - blc.actual_stake) > 0 THEN 'Won'
						WHEN SUM(blc.winlost - blc.actual_stake) < 0 THEN 'Lose'
						ELSE 'Draw'
					END AS Status,
					0 AS SettlementStatus,
					'' AS betstatus,
					CASE WHEN bcy.comstatus = '1' THEN 1 ELSE 0 END AS comstatus,
					SUM(blc.stake) AS stake,
					SUM(blc.actual_stake) AS actual_stake,
					SUM(blc.winlost - blc.actual_stake) AS WinLost,
					SUM(blc.playercomm) AS commission,
					0 AS livehomescore,
					0 AS liveawayscore,
					0 AS liveindicator,
					0 AS finalhomescore,
					0 AS finalawayscore,
					0 AS hthomescore,
					0 AS htawayscore,
					bcy.creator,
					bcy.ip,
					bcy.Username,
					0 AS IsNeutral,
					'' AS showtime,
					0 AS spositiontaking, -- unuse in this report
					0 AS mpositiontaking, -- unuse in this report
					0 AS apositiontaking, -- unuse in this report
					0 AS spositiontaking2,-- unuse in this report
					0 AS mpositiontaking2,-- unuse in this report
					0 AS apositiontaking2,-- unuse in this report
					0 AS scomm, -- unuse in this report
					0 AS acomm, -- unuse in this report
					0 AS comm,	-- unuse in this report
					SUM(blc.awinlost) AS awinlost,
					SUM(blc.mwinlost) AS mwinlost,
					SUM(blc.swinlost) AS swinlost,
					bcy.winlostdate,
					'' AS BetCheck,
					'' AS transdesc,
					CASE 
						WHEN s.SubProduct LIKE 'Jackpot%' THEN ISNULL(SUM(blc.BetStake), 0)
						ELSE 0
					END	
					AS OddsSpread,
					0 AS OriginalBetType,
					-1 AS BetdaqId,
					'' AS ExtraInfo,
					0 AS WalletType,
					0 AS RefCode,
					0 AS CurrencyId,
					'' AS SiteId,
					bcy.DeviceType
				FROM dbo.bettrans AS bcy WITH (NOLOCK)
					INNER JOIN dbo.bettransLC AS blc WITH (NOLOCK) ON blc.RefNo = bcy.transid
					INNER JOIN @SportBettype AS s ON s.Bettype = bcy.bettype
				WHERE bcy.custid = @CustId
					AND bcy.winlostdate = @FromDate
					AND (s.ProductID IN (11, 21, 39, 45, 46, 51, 52, 57, 65, 70, 76, 80) OR s.RefTable = 2)
					AND blc.statusID NOT IN (0, 1)
				GROUP BY
					bcy.transid,
					ISNULL(bcy.betid, 0),
					bcy.bettype,
					bcy.refno,
					bcy.transdate,
					bcy.winlostdate,
					bcy.custid,
					bcy.creator,
					bcy.ip,
					bcy.Username,
					bcy.comstatus,
					s.ProductID,
					bcy.matchid,
					bcy.DeviceType,
					blc.recommend,
					blc.mrecommend,
					s.SubProduct
				OPTION (RECOMPILE)
			END

			IF EXISTS (SELECT TOP(1) 1 FROM @tmpStatus WHERE [statusID] IN (0, 1))	-- yesterday and later running ticket
				AND @FromDate >= DATEADD(DAY, DATEDIFF(DAY, 1, GETDATE()), 0)
			BEGIN
				INSERT INTO @Data (
					SportType, LeagueId, HomeId, AwayId, MatchCode, Race, EventDate, VirtualRate, IsShowOTExRate,
					SDiscount, ADiscount, Discount, SettleTime, MatchId, TransId, BetId, RefNo, TransDate, OddsId,
					BetType, Hdp1, Hdp2, Odds, MOdds, FinalOdds, FinalOdds2, OddsType, BetTeam, Status,
					SettlementStatus, BetStatus, ComStatus, Stake, Actual_Stake, WinLost, Commission,
					LiveHomeScore, LiveAwayScore, LiveIndicator, FinalHomeScore, FinalAwayScore, HtHomeScore, HtAwayScore,
					Creator, Ip, Username, IsNeutral, ShowTime, SPositionTaking, MPositionTaking, APositionTaking,
					SPositionTaking2, MPositionTaking2, APositionTaking2, SComm, AComm, Comm, AWinLost, MWinLost, SWinLost,
					WinLostDate, BetCheck, TransDesc, OddsSpread, OriginalBetType, BetdaqId, ExtraInfo, WalletType,
					RefCode, CurrencyId, SiteId, DeviceType
				)
				SELECT
					CASE
						WHEN s.ProductID = 11 THEN 250
						WHEN s.ProductID = 21 THEN 211
						ELSE bc.matchid
					END AS Sporttype,
					0 AS leagueid,
					0 AS homeid,
					0 AS awayid,
					'' AS matchcode,
					'' AS race,
					'' AS eventdate,
					0,
					0,
					AVG(blc.sdiscount) AS sdiscount,
					CASE
						WHEN blc.mrecommend = -4 THEN 0
						ELSE AVG(blc.adiscount) 
					END AS adiscount,
					CASE
						WHEN blc.recommend IN (-3, -4) THEN 0
						ELSE AVG(blc.discount) 
					END AS discount,
					'' AS settletime,
					0 AS matchid,
					bc.transid,
					ISNULL(bc.betid, 0) AS betid,
					bc.refno,
					bc.transdate,
					0 AS oddsid,
					bc.bettype,
					0 AS hdp1,
					0 AS hdp2,
					0 AS odds,
					0 AS modds,
					0 AS finalodds,
					0 AS finalodds2,
					0 AS oddstype,
					'' AS betteam,
					'Running' AS Status,
					0 AS SettlementStatus,
					'' AS betstatus,
					CASE WHEN bc.comstatus = '1' THEN 1 ELSE 0 END AS comstatus,
					SUM(blc.stake) AS stake,
					SUM(blc.actual_stake) AS actual_stake,
					0 AS WinLost,
					0 AS commission,
					0 AS livehomescore,
					0 AS liveawayscore,
					0 AS liveindicator,
					0 AS finalhomescore,
					0 AS finalawayscore,
					0 AS hthomescore,
					0 AS htawayscore,
					bc.creator,
					bc.ip,
					bc.Username,
					0 AS IsNeutral,
					'' AS showtime,
					0 AS spositiontaking, -- unuse in this report
					0 AS mpositiontaking, -- unuse in this report
					0 AS apositiontaking, -- unuse in this report
					0 AS spositiontaking2,-- unuse in this report
					0 AS mpositiontaking2,-- unuse in this report
					0 AS apositiontaking2,-- unuse in this report
					0 AS scomm, -- unuse in this report
					0 AS acomm, -- unuse in this report
					0 AS comm,	-- unuse in this report
					0 AS awinlost,
					0 AS mwinlost,
					0 AS swinlost,
					bc.winlostdate,
					'' AS BetCheck,
					'' AS transdesc,
					0 AS OddsSpread,
					0 AS OriginalBetType,
					-1 AS BetdaqId,
					'' AS ExtraInfo,
					0 AS WalletType,
					0 AS RefCode,
					0 AS CurrencyId,
					'' AS SiteId,
					bc.DeviceType
				FROM dbo.bettrans AS bc WITH (NOLOCK)
					INNER JOIN dbo.bettransLC AS blc WITH (NOLOCK) ON blc.RefNo = bc.transid
					INNER JOIN @SportBettype AS s ON s.Bettype = bc.bettype
				WHERE bc.custid = @CustId
					AND bc.winlostdate = @FromDate
					AND (s.ProductID IN (11, 21, 39, 45, 46, 51, 52, 57, 65, 70, 76, 80) OR s.RefTable = 2)
					AND blc.statusID IN (0, 1)
				GROUP BY
					bc.transid,
					ISNULL(bc.betid, 0),
					bc.bettype,
					bc.refno,
					bc.transdate,
					bc.winlostdate,
					bc.custid,
					bc.creator,
					bc.ip,
					bc.Username,
					bc.comstatus,
					s.ProductID,
					bc.matchid,
					bc.DeviceType,
					blc.recommend,
					blc.mrecommend
				OPTION (RECOMPILE)
			END

			-- Bitcoin
			INSERT INTO @Data (
				SportType, LeagueId, HomeId, AwayId, MatchCode, Race, EventDate, VirtualRate, IsShowOTExRate,
				SDiscount, ADiscount, Discount, SettleTime, MatchId, TransId, BetId, RefNo, TransDate, OddsId,
				BetType, Hdp1, Hdp2, Odds, MOdds, FinalOdds, FinalOdds2, OddsType, BetTeam, Status,
				SettlementStatus, BetStatus, ComStatus, Stake, Actual_Stake, WinLost, Commission,
				LiveHomeScore, LiveAwayScore, LiveIndicator, FinalHomeScore, FinalAwayScore, HtHomeScore, HtAwayScore,
				Creator, Ip, Username, IsNeutral, ShowTime, SPositionTaking, MPositionTaking, APositionTaking,
				SPositionTaking2, MPositionTaking2, APositionTaking2, SComm, AComm, Comm, AWinLost, MWinLost, SWinLost,
				WinLostDate, BetCheck, TransDesc, OddsSpread, OriginalBetType, BetdaqId, ExtraInfo, WalletType,
				RefCode, CurrencyId, SiteId, DeviceType
			)
			SELECT
				m.sporttype,
				CASE
					WHEN s.ProductID = 69 THEN 0 
					ELSE m.League3rdId
				END AS leagueid,
				CASE 
					WHEN s.ProductID = 69 THEN 0 
					ELSE m.HomeId
				END AS homeid,
				CASE
					WHEN s.ProductID = 69 THEN 0
					ELSE m.AwayId
				END AS awayid,
				'' matchcode,
				'' AS race,
				m.EndTime AS EventDate,
				0,
				0,
				bic.sdiscount,
				CASE
					WHEN bic.mrecommend = -4 THEN 0
					ELSE bic.adiscount
				END,
				CASE
					WHEN bic.recommend IN (-3, -4) THEN 0
					ELSE bic.discount
				END,
				'' AS settletime,
				m.match3rdid,
				bic.transid,
				CASE
					WHEN s.ProductId = 71 THEN bic.BetID
					ELSE 0 
				END AS BetId,
				bic.refno,
				bic.transdate,
				0 oddsid,
				bic.bettype,
				bic.hdp1,
				CASE 
					WHEN s.ProductID = 69 THEN 0
					ELSE bic.hdp2
				END AS hdp2,
				bic.odds,
				0 modds,
				0 AS finalodds,
				0 AS finalodds2,
				bic.oddstype,
				bic.betteam,
				bic.status,
				0 AS SettlementStatus,
				'' AS betstatus,
				0 AS comstatus,
				bic.stake,
				bic.actual_stake,
				(bic.winlost - bic.actual_stake) AS WinLost,
				bic.playercomm,
				0 livehomescore,
				0 liveawayscore,
				CASE
					WHEN s.ProductID = 69 THEN 0
					ELSE bic.liveindicator
				END AS liveindicator,
				0 finalhomescore,
				0 finalawayscore,
				0 hthomescore,
				0 htawayscore,
				bic.creator,
				bic.ip,
				bic.Username,
				0 AS IsNeutral,
				CASE 
					WHEN s.ProductID = 71 THEN CONVERT(NVARCHAR(50), m.StartTime)
					ELSE '' 
				END AS ShowTime,
				bic.spositiontaking,
				bic.mpositiontaking,
				bic.apositiontaking,
				0 spositiontaking2,
				0 mpositiontaking2,
				0 apositiontaking2,
				(bic.scomm - bic.acomm) AS scomm,
				(bic.acomm - bic.comm) AS acomm,
				(bic.comm - bic.playercomm) AS comm,
				bic.awinlost,
				bic.mwinlost,
				bic.swinlost,
				bic.winlostdate,
				'' BetCheck,
				'' AS transdesc,
				0 AS OddsSpread,
				0 AS OriginalBetType,
				-1 AS BetdaqId,
				bic.ExtraInfo,
				0 AS WalletType,
				0 AS RefCode,
				0 AS CurrencyId,
				'' AS SiteId,
				bic.DeviceType
			FROM dbo.bettrans AS bic WITH (NOLOCK)
				INNER JOIN @SportBettype AS s ON s.Bettype = bic.bettype
				INNER JOIN dbo.match3rd AS m WITH (NOLOCK) ON bic.matchid = m.match3rdid
			WHERE bic.custid = @CustId
				AND bic.winlostdate = @FromDate
				AND bic.statusID IN (SELECT [statusID] FROM @tmpStatus)
		END

		-- Grand Prize Jackpot Win
		IF @TransType = 4
		BEGIN
			-- ONERnG Jackpot
			INSERT INTO @Data (
				SportType, LeagueId, HomeId, AwayId, MatchCode, Race, EventDate, VirtualRate, IsShowOTExRate,
				SDiscount, ADiscount, Discount, SettleTime, MatchId, TransId, BetId, RefNo, TransDate, OddsId,
				BetType, Hdp1, Hdp2, Odds, MOdds, FinalOdds, FinalOdds2, OddsType, BetTeam, Status,
				SettlementStatus, BetStatus, ComStatus, Stake, Actual_Stake, WinLost, Commission,
				LiveHomeScore, LiveAwayScore, LiveIndicator, FinalHomeScore, FinalAwayScore, HtHomeScore, HtAwayScore,
				Creator, Ip, Username, IsNeutral, ShowTime, SPositionTaking, MPositionTaking, APositionTaking,
				SPositionTaking2, MPositionTaking2, APositionTaking2, SComm, AComm, Comm, AWinLost, MWinLost, SWinLost,
				WinLostDate, BetCheck, TransDesc, OddsSpread, OriginalBetType, BetdaqId, ExtraInfo, WalletType,
				RefCode, CurrencyId, SiteId, DeviceType
			)
			SELECT
				CASE
					WHEN s.ProductID = 6 THEN bp.productID
					ELSE 0
				END AS SportType,
				0 AS leagueid,
				0 AS homeid,
				0 AS awayid,
				'' AS matchcode,
				'' AS race,
				'' AS eventdate,
				0,
				0,
				0 AS sdiscount,
				0 AS adiscount,
				0 AS discount,
				'' AS settletime,
				0 AS matchid,
				bp.transid,
				0 AS BetId,
				bp.RefNo,
				bp.transdate,
				0 AS oddsid,
				bp.gameID AS BetType,
				0 AS hdp1,
				0 AS hdp2,
				bp.odds,
				0 AS modds,
				0 AS finalodds,
				0 AS finalodds2,
				0 AS oddstype,
				'' AS betteam,
				bp.status,
				0 AS SettlementStatus,
				'' AS betstatus,
				0 AS comstatus,
				bp.stake,
				bp.actual_stake,
				CASE
					WHEN s.ProductID = 6 THEN (bp.winlost - bp.actual_stake)
					ELSE 0
				END AS WinLost,
				CASE
					WHEN s.ProductID = 6 THEN bp.playercomm
					ELSE 0
				END AS PlayerComm,
				0 AS livehomescore,
				0 AS liveawayscore,
				0 AS liveindicator,
				0 AS finalhomescore,
				0 AS finalawayscore,
				0 AS hthomescore,
				0 AS htawayscore,
				bp.creator,
				bp.ip,
				bp.Username,
				0 AS IsNeutral,
				'' AS showtime,
				0 AS spositiontaking, -- unuse in this report
				0 AS mpositiontaking, -- unuse in this report
				0 AS apositiontaking, -- unuse in this report
				0 AS spositiontaking2,-- unuse in this report
				0 AS mpositiontaking2,-- unuse in this report
				0 AS apositiontaking2,-- unuse in this report
				0 AS scomm, -- unuse in this report
				0 AS acomm, -- unuse in this report
				0 AS comm,	-- unuse in this report
				0 AS awinlost,
				0 AS mwinlost,
				0 AS swinlost,
				pt.winlostdate,
				bp.TranId3rd AS BetCheck,
				bp.transdesc,
				0 AS OddsSpread,
				0 AS OriginalBetType,
				CASE
					WHEN s.ProductID = 6 THEN ISNULL(bp.RefNo2, -1)
					ELSE -1
				END AS BetdaqId,
				'' AS ExtraInfo,
				0 AS WalletType,
				0 AS RefCode,
				0 AS CurrencyId,
				'' AS SiteId,
				bp.DeviceType
			FROM DBACC.bodb02.dbo.PayoutTrans AS pt WITH (NOLOCK)
				INNER JOIN dbo.bettransRnG AS bp WITH (NOLOCK) ON pt.RefNo = bp.transid
				INNER JOIN @SportBettype AS s ON s.Bettype = bp.gameID
			WHERE pt.custid = @CustId
				AND pt.winlostdate = @FromDate
				AND (s.ProductID = 6 AND pt.PayoutStatus IN ('Completed', 'Expired'))
				AND bp.statusID IN (SELECT [statusID] FROM @tmpStatus)
		END
	END

	-- Get original odds for Mix Parlay and final odds, boost rate for Mix Parlay Boost Bonus
	IF EXISTS (SELECT 1 FROM @Data WHERE BetType = 29 AND BetTeam = '1' AND OddsSpread <> 3)
	BEGIN
		-- Running/Waiting
		DECLARE @ParlayData TABLE (
			RefNo		BIGINT,
			BoostRate	MONEY)

		INSERT INTO @ParlayData (RefNo, BoostRate)
		SELECT
			b.refno,
			CASE
				WHEN b.bettype = 29 AND b.betteam = 1 AND b.oddsspread = 2 THEN
					ISNULL(CAST(('<xml>' + b.ExtraInfo + '</xml>') AS XML).value('data(/xml/p1/@bbp)[1]','MONEY'), 0)
				ELSE 0
			END AS BoostRate
		FROM @Data AS b
		WHERE b.BetType = 29
			AND b.BetTeam = '1'
			AND b.Status IN ('Running', 'Waiting')

		DECLARE @TmpParlayData TABLE (
			RefNo	BIGINT,
			Odds	MONEY,
			MOdds	MONEY)

		-- Mix Parlay which having at least 1 settled sub ticket
		INSERT INTO @TmpParlayData(RefNo, Odds, MOdds)
		SELECT
			b.RefNo,
			dbo.PRODUCT(bpd.odds) AS Odds,
			dbo.PRODUCT(bpd.odds) * (b.BoostRate + 1) - b.BoostRate AS MOdds
		FROM @ParlayData AS b
			INNER JOIN dbo.BetParlayDetail AS bpd WITH (NOLOCK) ON bpd.RefNo = b.RefNo
		GROUP BY
			b.RefNo,
			b.BoostRate

		-- Mix Parlay which having no settled sub ticket
		UNION ALL
		SELECT
			b.RefNo,
			dbo.PRODUCT(bm.odds) AS Odds,
			dbo.PRODUCT(bm.odds) * (b.BoostRate + 1) - b.BoostRate AS MOdds
		FROM @ParlayData AS b
			INNER JOIN dbo.bettransm AS bm WITH (NOLOCK) ON bm.refno = b.RefNo
		WHERE NOT EXISTS (SELECT 1 FROM @TmpParlayData WHERE RefNo = b.RefNo)
		GROUP BY
			b.RefNo,
			b.BoostRate

		UPDATE b
		SET
			b.Odds = td.Odds,
			b.MOdds = td.MOdds
		FROM @Data AS b
			INNER JOIN @TmpParlayData AS td ON td.RefNo = b.RefNo

		-- Settled
		UPDATE b
		SET
			b.Odds = bpr.Odds,
			b.Modds = bpr.mOdds,
			b.TransDesc = IIF(b.OddsSpread = 3,b.TransDesc, CONVERT(VARCHAR(20), ISNULL(bpr.ExtraValue, '')))
		FROM @Data AS b
			INNER JOIN dbo.BetParlayResult AS bpr WITH (NOLOCK) ON bpr.RefNo = b.RefNo
		WHERE b.BetType = 29
			AND b.BetTeam = '1'
			AND b.Status NOT IN ('Running', 'Waiting')
	END

	UPDATE tblTemp
	SET tblTemp.Creator = cu.username
	FROM @Data AS tblTemp
		INNER JOIN dbo.Customer AS cu WITH (NOLOCK) ON cu.custid = tblTemp.Creator;

	-- Get currency name
	DECLARE @CurrencyName NVARCHAR(50)

	SELECT @CurrencyName = ex.currency
	FROM dbo.custInfo AS ci WITH (NOLOCK)
		INNER JOIN dbo.Exchange AS ex WITH (NOLOCK) ON ci.currency = ex.exchangeid
	WHERE ci.custid = @CustId

	-- Get data for summary ticket of multiple Bonus/Cash sub tickets
	IF EXISTS (SELECT 1 FROM @Data WHERE RefCode <> 0)
	BEGIN
		DECLARE @RefCodeTmp TABLE (
			RefCode			BIGINT,
			TransId			BIGINT,
			Stake			MONEY,
			Actual_Stake	MONEY,
			WinLost			MONEY,
			Commission		MONEY,
			SWinLost		MONEY,
			MWinLost		MONEY,
			AWinLost		MONEY,
			SComm			MONEY,
			AComm			MONEY,
			Comm			MONEY
		)

		INSERT INTO @RefCodeTmp (RefCode, TransId, Stake, Actual_Stake, WinLost, Commission, SWinLost, MWinLost, AWinLost, SComm, AComm, Comm)
		SELECT
			RefCode,
			MIN(TransId) AS TransId,
			SUM(Stake) AS Stake,
			SUM(Actual_Stake) AS Actual_Stake,
			SUM(WinLost) AS WinLost,
			SUM(Commission) AS Commission,
			SUM(SWinLost) AS SWinLost,
			SUM(MWinLost) AS MWinLost,
			SUM(AWinLost) AS AWinLost,
			SUM(SComm) AS SComm,
			SUM(AComm) AS AComm,
			SUM(Comm) AS Comm
		FROM @Data
		WHERE RefCode <> 0
		GROUP BY RefCode
		HAVING COUNT(1) > 1

		IF EXISTS (SELECT 1 FROM @RefCodeTmp)
		BEGIN
			-- Update data for summmary ticket
			UPDATE b
			SET
				b.Stake = r.Stake,
				b.Actual_Stake = r.Actual_Stake,
				b.WinLost = r.WinLost,
				b.Commission = r.Commission,
				b.SWinLost = r.SWinLost,
				b.MWinLost = r.MWinLost,
				b.AWinLost = r.AWinLost,
				b.SComm = r.SComm,
				b.AComm = r.AComm,
				b.Comm = r.Comm,
				b.WalletType = 0
			FROM @Data AS b
				INNER JOIN @RefCodeTmp AS r ON b.RefCode = r.RefCode AND b.TransId = r.TransId

			-- Delete 2nd Bonus/Cash tickets
			DELETE @Data
			WHERE WalletType <> 0
				AND RefCode IN (SELECT RefCode FROM @RefCodeTmp)
		END
	END

	-- Display detail link for ticket from Bonus Wallet only
	UPDATE @Data
	SET RefCode = TransId
	WHERE WalletType = 1 AND RefCode = 0

	-- Don't display Cash text for ticket from Cash Wallet only
	UPDATE @Data
	SET WalletType = 0
	WHERE WalletType = 2 AND RefCode = 0

	SELECT 
		SportType,
		LeagueId,
		HomeId,
		AwayId,
		MatchCode,
		Race,
		EventDate,
		VirtualRate,
		IsShowOTExRate,
		SDiscount,
		ADiscount,
		Discount,
		SettleTime,
		MatchId,
		TransId,
		BetId,
		RefNo,
		TransDate,
		OddsId,
		BetType,
		Hdp1,
		Hdp2,
		Odds,
		MOdds,
		FinalOdds,
		FinalOdds2,
		OddsType,
		BetTeam,
		Status,
		SettlementStatus,
		BetStatus,
		ComStatus,
		Stake,
		Actual_Stake,
		WinLost,
		Commission,
		LiveHomeScore,
		LiveAwayScore,
		LiveIndicator,
		FinalHomeScore,
		FinalAwayScore,
		HtHomeScore,
		HtAwayScore,
		Creator,
		Ip,
		Username,
		IsNeutral,
		ShowTime,
		SPositionTaking,
		MPositionTaking,
		APositionTaking,
		SPositionTaking2,
		MPositionTaking2,
		APositionTaking2,
		SComm,
		AComm,
		Comm,
		AWinLost,
		MWinLost,
		SWinLost,
		WinLostDate,
		BetCheck,
		TransDesc,
		OddsSpread,
		OriginalBetType,
		BetdaqId,
		ExtraInfo,
		WalletType,
		RefCode,
		CurrencyId,
		SiteId,
		DeviceType,
		@CurrencyName AS Currency
	FROM @Data
	ORDER BY TransId ASC
END
GO
