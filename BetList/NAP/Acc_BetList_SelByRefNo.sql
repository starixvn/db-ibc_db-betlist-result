/*<info serverAlias="DBACC-bodb02" executers="wsv_nap" viewers="" isFunction="0" isNested="0"></info>*/

ALTER PROCEDURE [dbo].[Acc_BetList_SelByRefNo]
	@RefNo				BIGINT,
	@MoveBetsDay		SMALLDATETIME,
	@BalanceUpDay		SMALLDATETIME,
	@Permission			VARCHAR(20)		= '1,2,3',
	@ExcludeBettrans	BIT				= 0,
	@DeniedList			VARCHAR(MAX) = ''
AS

/*
	Created by: 20121212@Elodie
	Task: Get tickets by RefNo (display in column RefNo in bet list)
	DB: DBACC.bodb02

	Parameter Explanantion
		- @Permission
			- 1: Credit sites
			- 2: Deposit sites
			- 3: CN88
	
	Revisions:
		- 20130121@Dan: change linked server DB06 to DBARC
		- 20130227@Elodie: Add Virtual HR product
		- 20130724@Elodie: Get winlostdate field
		- 20130726@Elodie: Define data for bettrans, bettrans14, bettrans_bk by winlostdate field
		- 20140907@Dom: [Redmine #22012] update VS Condition
		- 20141103@Dom: Apply sport bettype matrix
		- 20150415@Sophia: Support Betradar and revise code of Bettype matrix
		- 20150506@Tom: Support Gold Deluxe Product [#34847]
		- 20150506@Bobby: Add transdesc column for metric gaming bettypes (801-899)
		- 20150615@Edward: Support for BetTrade
		- 20150707@Bobby: Exclude Metric Gaming running ticket from bettrans table
		- 20150805@Bobby:
			+ Dis-allow to get ticket detail by refno 
			+ remove checking product when selecting ticket's eventtype = 1 from bettrans_bk
		- 20150814@Bobby: Fix bug #41544 - Exclude CS, BG, GD, KN, MG, MGC tickets
		- 20150826@Kos: Add OddsSpread column to support Myanmar Odds
		- 20150826@Kos: Exclude Colossus Bet ticket
		- 20151008@Kos: Exclude AG Casino ticket
		- 20151008@Kos: Exclude Microgaming RNG Casino ticket
		- 20151210@Kos: Change odds, modds data type from SMALLMONEY to MONEY [Redmine: #48660]
		- 20151216@Kos: Exclude Cockfighting ticket [#Redmine: 48850]
		- 20160119@Kos: Support PH All In One 1.2 [#Redmine: 50897]
		- 20160203@Kos: Support AllBet [#Redmine: 50257]
		- 20160609@Kos: Support search 3rd tickets in range bettrans and bettrans14 [#Redmine: 55051]
				+ Move SP from DBAGE to DBACC
				+ Don't support Bingo and P2P in bettrans and bettrans14 range anymore
				+ Apply SportBetTypeMatrix function
		- 20160623@Kos: Hide special sites from unauthorized users [#Redmine: 48948]
		- 20160804@Kos: Exclude bet type 904 [#Redmine: 58978]
		- 20160810@Kos: Support NG2
		- 20161017@Kos: Support search all AllBet related tickets [#Redmine: 65802]
		- 20161019@Kos: Support Fishing World [#Redmine: 65934]
		- 20170228@Kos: Support KickOffTime for Virtual Soccer and Virtual Tennis [#Redmine: 71906]
		- 20170315@Kos: Support CashOut [#Redmine: 71963]
		- 20170602@Kos: Get liveindicator from original ticket for 911 and 912 tickets [#Redmine: 77669]
		- 20170620@Kos: Support Betradar Virtual Sports [#Redmine: 77280]
		- 20170629@Kos: Support Keno Lottery [#Redmine: 77929]
		- 20170718@Kos: Don't parse transdesc for Keno anymore [#Redmine: 80082]
		- 20170829@Kos: Support Lucky 3 [#Redmine: 75277]
		- 20171024@Kos: Support Bullfighting [#Redmine: 84961]
		- 20171227@Kos: Return ticket detail of Racing and Virtual Horse Racing [#Redmine: 88775]
					- Don't support Live Casino in bettrans and bettrans14 anymore
		- 20180118@Kos: Support Licensee Bonus System [#Redmine: 74978]
		- 20180130@Kos: Don't support Racing and RNG Casino (bettype 71, 72) in bettrans and bettrans14 [#Redmine: 86086]
					- Don't support Cockfighting anymore
		- 20180302@Kos: Support ONERnG Jackpot [#Redmine: 88652]
		- 20180405@Kos: Support Pragmatic Casino [#Redmine: 92160]
		- 20180510@Kos: Support Keno 6 new Mini Games [#Redmine: 93759]
		- 20180515@Kos: Add Match No for Bullfighting [#Redmine: 84961]
		- 20180709@Kos: Support Poker Games [#Redmine: 97565]
		- 20180808@Helen: DB05.DBPOLICY migration [#Redmine: 99462]
		- 20180927@Kos: Add new permission to view Licensee account [#Redmine: 96118]
		- 20181114@Kos: Change getting ticket status [#Redmine: 104664]
		- 20181121@Kos: Support new status Result Pending and Under Settlement [#Redmine: 101949]
		- 20181218@Kos: Support E-Sports phase 2b [#Redmine: 106456]
		- 20190107@Kos: Support Parlay Changes [#Redmine: 105585]
		- 20190321@Kos: Support Pragmatic Promotion Prize [#Redmine: 108117]
		- 20190503@Kos: Show match KO time for single ticket [#Redmine: 112092]
		- 20190531@Kos: Add new input param @Permission VARCHAR(20) [#Redmine: 114125]
					- Remove param @SiteType
		- 20190611@Kos: Support Card Club [#Redmine: 107645]
					- Don't support Poker Games in bettrans and bettrans14 range anymore
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
		- 20200731@Kos: Support Saba.club Result [Redmine: #137680]
		- 20200808@Kos: Support PG Soft [Redmine: #137769]
		- 20200919@Kos: Support Joker [Redmine: #137942]
		- 20200930@Kos: Support GameId3rd for PG Soft [Redmine: #137769]
		- 20201001@Kos: Support WM Live Casino [Redmine: #131588]
		- 20201123@Kos: Support God Of Fortune [Redmine: #145834]
		- 20201203@Kos: Support GDG [Redmine: #144104]
		- 20201217@Kos: Support Leap Gaming Virtual Sports 3 [Redmine: #131371]
		- 20201218@Kos: Support SiteId for GDG [Redmine: #147084]
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
		- 20211025@Razor: Decompress IP on BK range [Redmine: #90903]
		- 20211125@Razor: Rename RNG War to Funky Games [Redmine: #132024]
		- 20211222@Razor: BBIN Support Third Party Result API [Redmine: #165158]
		- 20220106@Razor: Fix CurrencyId is NULL on SA Gaming [Redmine: #167043]
		- 20220112@Razor: Support Third Party Result API [Redmine: #165815]
		- 20220209@Razor: Support TxId for 3rd products [Redmine: #167320]
		- 20220215@Razor: VGaming, Sabaclub return SiteId on MatchCode property
		- 20220215@Razor: Support SG Jackpot [Redmine: #166683]
		- 20220225@Razor: Hide Saba word in league name for China View licensee [Redmine: #169101]
		- 20220317@Razor: Support FGG [Redmine: #165683]
		- 20220324@Razor: Support TxId for VGaming [Redmine: #170054]
		- 20220422@Razor: Support Virtual games result [Redmine: #170997]
		- 20220729@Kos: Scale out DBTRANS [Redmine: #175253]
					- Add new input param @ExcludeBettrans BIT, @Site VARCHAR(10)
		- 20220825@Razor: Support SEAL Entertainment [Redmine: #176210]
		- 20220909@Razor: Support Microgaming RNG Casino [Redmine: #175851]
		- 20221010@Kos: Scale out DBTRANS [Redmine: #178943]
					- Remove param @Site
		- 20221117@Razor: Support Player Tips [Redmine: #180590]
		- 20230206@Razor: Support Jili [Redmine: #182864]
		- 20230417@Razor: Remove Betfrom column [Redmine: #126137]
		- 20230526@Razor: Support YeeBet [Redmine: #186547]
		- 20230704@Razor: Remove Related tickets ION [Redmine: #190827]
		- 20230727@Razor: Support Virtual Sports 3 [Redmine: #189205]
		- 20230830@Razor: Show LicTxId for MaxGame [Redmine: #193273]
		- 20230909@Razor: Remove GDG, Fishing World products [Redmine: #174511]
		- 20230909@Razor: Remove GD, Colossusbet products [Redmine: #179132]
		- 20231005@Kos: Support Parlay Boost [Redmine: #194992]
		- 20231020@Razor: Support show max payout [Redmine: #194491]
					- Return new JackpotInfo column
					- Return ExtraInfo for show Max Payout
		- 20231027@Razor: Support new bettype of Virtual Sport 3 (LG) [Redmine: #194634]
		- 20231101@Razor: Return Device Type info [Redmine: #192667]
		- 20231108@Razor: Support WE Live Casino [Redmine: #195887]
		- 20231215@Razor: Support Live22 [Redmine: #197609]
		- 20240105@Razor: Extend data type [Redmine: #199259]
		- 20240207@Kos: Return GameId3rd to support Live22 Result [Redmine: #197609]
		- 20240222@Razor: Support Project 777 - return SpecialPlatfrom [Redmine: #194591]
		- 20240222@Razor: Support Vitual Sports 4 [Redmine: #198619]
		- 20240327@Kos: Support UU Slots [Redmine: #192600]
		- 20240411@Razor: Return TranId3rd for Running ticket of Virtual Games/SportsLottery [Redmine: #203734]
		- 20240417@Razor: Support Saba xD [Redmine: #203371]
		- 20240419@Razor: Support Saba Coins [Redmine: #204003]
		- 20240507@Razor: Check permission for Real Currency [Redmine: #202523]
		- 20240626@Razor: Support FastSpin [Redmine: #205742]
		- 20240912@Razor: Support ON Casino [Redmine: #210026]
		- 20241003@Razor: Remove Linked Server on DBCust [Redmine: #206893]
		- 20241003@Razor: Support VS2 Racing sports [Redmine: #211092]
		- 20241106@Razor: Support VS 5 - Virtually Sports [Redmine: #207589]
		- 20241202@Razor: Support GPI Live Casino [Redmine: #213486]
		- 20241219@Razor: Support VS6 - Betby Virtual Sports [Redmine: #212546]
		- 20250326@Benji: Support Upcoming Product (Microgaming Live Casino, Playtech Live Casino ) [Redmine: #221188]
		- 20250410@Benji: Remove Unnecessary Returned Data (Microgaming Live Casino, Playtech Live Casino) [Redmine: #221188]
		- 20250414@Razor: Support Direct Member [Redmine: #211969]
		- 20250423@Dave: Change datatype for ExchangeID [RedmineID: #225169]
		- 20250730@Benji: Support Playtech RNG Jackpot - Support Automate Integration for Jackpot Betlist [Redmine: #234576]
		- 20250819@Razor: Support VS 2 - VS Tournament [Redmine: #235084]
		- 20250820@Benji: Support Playtech Live Jackpot [Redmine: #230127]
		- 20251027@Bobby: Support BetBuilder Hybrid Parlay [Redmine: #242255]
*/

BEGIN
	SET NOCOUNT ON

	-- Get Sport Bettype Matrix --
	DECLARE @SportBettype TABLE (ProductID TINYINT, BetType SMALLINT, EventType TINYINT, SubProduct VARCHAR(500), RefTable TINYINT)

	DECLARE @IsTest BIT = 0

	SELECT @IsTest = dbo.f_CheckSPVersion(@@PROCID)

	INSERT INTO @SportBettype (ProductID, BetType, EventType, SubProduct, RefTable)
	SELECT ProductID, BetType, EventType, SubProduct, RefTable
	FROM dbo.f_SportBettypeMatrix_Sel (0, 0, 0, 2, '', '', @IsTest)
	WHERE BetType NOT IN (903, 904, 913, 914)
		AND ProductID NOT IN (2, 4, 7, 9, 13, 17, 19, 24, 26, 30, 31, 33)

	DECLARE
		@TransId		BIGINT,
		@BetType		INT,
		@WinLostDate	SMALLDATETIME,
		@CustId			INT
	DECLARE @ProductJackpot TABLE(ProductId TINYINT)
	
	INSERT INTO @ProductJackpot (ProductId)
    SELECT DISTINCT ProductId
    FROM @SportBettype
    WHERE SubProduct LIKE 'Jackpot%'
	
	IF @ExcludeBettrans = 0
	BEGIN
		-- FROM translog
		SELECT TOP(1)
			@TransId = b.translogid,
			@BetType = b.gameID,
			@WinLostDate = b.winlostdate,
			@CustId = b.custid
		FROM dbo.translog AS b WITH (NOLOCK)
			INNER JOIN @SportBettype AS sp ON b.gameID = sp.bettype
		WHERE b.translogid = @RefNo
			AND b.statusID IN (0, 1)
			AND ( sp.productid IN (8, 28, 38, 40, 43, 49, 63)
				OR sp.bettype BETWEEN 801 AND 899
				OR (sp.productid = 3 AND sp.EventType = 0))

		-- FROM bettrans (exclude Metric Gaming running ticket)
		IF @WinLostDate IS NULL
		BEGIN
			SELECT TOP(1)
				@TransId = b.transid,
				@BetType = b.bettype,
				@WinLostDate = b.winlostdate,
				@CustId = b.custid
			FROM dbo.bettrans AS b WITH (NOLOCK)
				INNER JOIN @SportBettype AS sp ON b.bettype = sp.bettype
			WHERE
				( b.transid = @RefNo
					OR ( b.refno = @RefNo
						AND (sp.productid IN (8, 28, 38, 40, 43, 49, 63)
							OR sp.bettype BETWEEN 801 AND 899
							OR (sp.productid = 3 AND sp.EventType = 0) ) ) )
				AND (b.bettype NOT BETWEEN 801 AND 806
					OR b.statusID NOT IN (0, 1))
		END
	END

	-- FROM bettrans14
	IF @WinLostDate IS NULL
	BEGIN
		SELECT TOP(1)
			@TransId = b.transid,
			@BetType = b.bettype,
			@WinLostDate = b.winlostdate,
			@CustId = b.custid
		FROM dbo.bettrans14 AS b WITH (NOLOCK)
			INNER JOIN @SportBettype AS sp ON b.bettype = sp.bettype
		WHERE b.transid = @RefNo
			OR ( b.refno = @RefNo
				AND (sp.productid IN (8, 28, 38, 40, 43, 49, 63)
					OR sp.bettype BETWEEN 801 AND 899
					OR (sp.productid = 3 AND sp.EventType = 0)))
	END

	-- FROM bettrans_bk
	IF @WinLostDate IS NULL
	BEGIN
		SELECT TOP(1)
			@TransId = b.transid,
			@BetType = b.bettype,
			@WinLostDate = b.winlostdate,
			@CustId = b.custid
		FROM bodb_Archive.dbo.bettrans_bk AS b WITH (NOLOCK)
			INNER JOIN @SportBettype AS sp ON b.bettype = sp.bettype
		WHERE b.transid = @RefNo
	END

	DECLARE @Data TABLE (
		BetType				INT,
		TransId				BIGINT,
		BetId				BIGINT,
		RefNo				NVARCHAR(50),
		MatchCode			NVARCHAR(1000),
		Race				NVARCHAR(20),
		EventDate			DATETIME,
		VirtualRate			FLOAT,
		IsShowOTExRate		BIT,
		SDiscount			SMALLMONEY,
		ADiscount			SMALLMONEY,
		Discount			SMALLMONEY,
		HomeId				INT,
		AwayId				INT,
		SettleTime			DATETIME,
		Hdp1				SMALLMONEY,
		Hdp2				SMALLMONEY,
		Odds				MONEY,
		FinalOdds			MONEY,
		FinalOdds2			MONEY,
		OddsType			TINYINT,
		Status				NVARCHAR(50),
		SettlementStatus	TINYINT,
		ComStatus			NVARCHAR(50),
		Stake				MONEY,
		Actual_Stake		MONEY,
		TransDate			DATETIME,
		BetTeam				NVARCHAR(200),
		SPositionTaking		SMALLMONEY,
		MPositionTaking		SMALLMONEY,
		APositionTaking		SMALLMONEY,
		SPositionTaking2	SMALLMONEY,
		MPositionTaking2	SMALLMONEY,
		APositionTaking2	SMALLMONEY,
		LiveIndicator		BIT,
		Modds				MONEY,
		CustId				INT,
		LiveHomeScore		INT,
		LiveAwayScore		INT,
		FinalHomeScore		INT,
		FinalAwayScore		INT,
		LeagueId			INT,
		SportType			INT,
		Ip					VARCHAR(45),
		MatchId				INT,
		IsNeutral			BIT,
		WinLost				MONEY,
		Commission			MONEY,
		SComm				MONEY,
		AComm				MONEY,
		Comm				MONEY,
		AWinLost			MONEY,
		MWinLost			MONEY,
		SWinLost			MONEY,
		ShowTime			NVARCHAR(50),
		WinLostDate			SMALLDATETIME,
		BetCheck			NVARCHAR(2000),
		TransDesc			NVARCHAR(1000),
		OddsSpread			MONEY,
		OriginalBetType		INT,
		BetdaqId			BIGINT,
		ExtraInfo			VARCHAR(1000),
		JackpotInfo			VARCHAR(50),
		WalletType			TINYINT,
		RefCode				BIGINT,
		CurrencyId			SMALLINT,
		SiteId				VARCHAR(20),
		LeagueGroupId		SMALLINT,
		DeviceType			TINYINT
	)

	DECLARE @DeniedSite TABLE (
		SiteId			INT,
		Site			NVARCHAR(50))

	DECLARE @DeniedCurrency TABLE (
		ExchangeId			INT)

	IF @DeniedList <> ''
	BEGIN
		INSERT INTO @DeniedSite (siteid, site)
		SELECT vl.ID, vl.Name
		FROM OPENJSON(@DeniedList) 
				WITH (  [KeyName]	VARCHAR(30),
						[Value]	NVARCHAR(MAX) AS JSON
					) AS js
		CROSS APPLY OPENJSON (js.[value])
				WITH (  [ID]	INT,
						[Name]	NVARCHAR(30),
						[Opt]	TINYINT
					) AS vl
		WHERE js.[KeyName]='Site'

		INSERT INTO @DeniedCurrency (ExchangeId)
		SELECT vl.ID
		FROM OPENJSON(@DeniedList) 
				WITH (  [KeyName]	VARCHAR(30),
						[Value]		NVARCHAR(MAX) AS JSON
					) AS js
		CROSS APPLY OPENJSON (js.[value])
				WITH (  [ID]	INT,
						[Name]	NVARCHAR(30),
						[Opt]	TINYINT
					) AS vl
		WHERE js.[KeyName]='Exchange'
	END

	INSERT INTO @DeniedSite (SiteId, Site)
	SELECT
		s.siteid,
		s.site
	FROM dbo.Site AS s WITH (NOLOCK)
	WHERE NOT EXISTS (SELECT 1 FROM @DeniedSite WHERE SiteId = s.siteid)
		AND ((s.isLicensee = 0									-- Don't have Credit sites permission
				AND s.site <> 'cn88'
				AND ',' + @Permission + ',' NOT LIKE '%,1,%')
			OR (s.isLicensee = 1								-- Don't have Deposit sites permission
				AND s.site <> 'cn88'
				AND ',' + @Permission + ',' NOT LIKE '%,2,%')
			OR (s.site = 'cn88'									-- Don't have CN88 site permission
				AND ',' + @Permission + ',' NOT LIKE '%,3,%'))

	IF @WinLostDate IS NOT NULL
		AND NOT EXISTS ( SELECT 1
						FROM dbo.customer AS c WITH (NOLOCK)
							INNER JOIN dbo.customer AS a WITH (NOLOCK) ON c.recommend = a.custid
						WHERE c.custid = @CustId
							AND a.site IN (SELECT Site FROM @DeniedSite))
		AND NOT EXISTS ( SELECT 1
						FROM dbo.customer AS c WITH (NOLOCK)
						WHERE c.custid = @CustId
							AND c.currency IN (SELECT ExchangeId FROM @DeniedCurrency))
	BEGIN
		-- Bettrans
		IF @WinLostDate > @MoveBetsDay
		BEGIN
			-- Sportbooks, Number Game, Virtual Sports, BetRadar Virtual Sports, Cash Out, Virtual Sports 3, Virtual Sports 4 (EventType = 1)
			IF EXISTS (SELECT TOP(1) 1 FROM @SportBettype WHERE EventType = 1 AND BetType = @BetType)
			BEGIN
				INSERT INTO @Data (
					BetType, TransId, BetId, RefNo, MatchCode, Race, EventDate, VirtualRate, IsShowOTExRate,
					SDiscount, ADiscount, Discount, HomeId, AwayId, SettleTime, Hdp1, Hdp2, Odds, FinalOdds,
					FinalOdds2, OddsType, Status, SettlementStatus, ComStatus, Stake, Actual_Stake, TransDate,
					BetTeam, SPositionTaking, MPositionTaking, APositionTaking, SPositionTaking2, MPositionTaking2,
					APositionTaking2, LiveIndicator, Modds, CustId, LiveHomeScore, LiveAwayScore, FinalHomeScore,
					FinalAwayScore, LeagueId, SportType, Ip, MatchId, IsNeutral, WinLost, Commission, SComm,
					AComm, Comm, AWinLost, MWinLost, SWinLost, ShowTime, WinLostDate, BetCheck, TransDesc,
					OddsSpread, OriginalBetType, BetdaqId, ExtraInfo, JackpotInfo, WalletType, RefCode,
					CurrencyId, SiteId, LeagueGroupId, DeviceType
				)
				SELECT
					b.bettype,
					b.transid,
					ISNULL(b.betid, 0) AS BetId,
					b.refno,
					m.matchcode,
					'' AS Race,
					CASE
						WHEN s.ProductID IN (1, 25) THEN m.GlobalShowTime
						ELSE m.eventdate
					END AS EventDate,
					0 AS VirtualRate,
					0 AS IsShowOTExRate,
					b.sdiscount,
					CASE
						WHEN b.mrecommend = -4 THEN 0
						ELSE b.adiscount
					END,
					CASE
						WHEN b.recommend IN (-3, -4) THEN 0
						ELSE b.discount
					END,
					m.homeid,
					m.awayid,
					ISNULL(b.checktime,'') AS SettleTime,
					b.hdp1,
					b.hdp2,
					b.odds,
					0 AS finalodds,
					0 AS finalodds2,
					b.OddsType,
					CASE
						WHEN b.status = 'running' AND ISNULL(b.SecAcceptFlag, 0) = 1 AND ISNULL(b.checktime, CURRENT_TIMESTAMP) > CURRENT_TIMESTAMP THEN 'waiting'
						ELSE b.status
					END AS status,
					ISNULL(m.SettlementStatus, 0) AS SettlementStatus,
					CASE WHEN b.comstatus = '1' THEN 1 ELSE 0 END AS comstatus,
					b.stake,
					b.actual_stake,
					b.transdate,
					b.betteam,
					b.spositiontaking,
					b.mpositiontaking,
					b.apositiontaking,
					0 AS SPositionTaking2,
					0 AS MPositionTaking2,
					0 AS APositionTaking2,
					b.liveindicator,
					b.modds,
					b.custid,
					b.livehomescore,
					b.liveawayscore,
					m.finalhomescore,
					m.finalawayscore,
					m.leagueid,
					m.sporttype,
					b.ip,
					b.matchid,
					ISNULL(m.isNeutral, CONVERT(BIT,0)) AS IsNeutral,
					(b.winlost - b.actual_stake) AS winlost,
					b.playercomm AS Commission,
					(b.scomm - b.acomm) AS scomm,
					(b.acomm - b.comm) AS acomm,
					(b.comm - b.playercomm) AS comm,
					b.awinlost,
					b.mwinlost,
					b.swinlost,
					CASE
						WHEN s.ProductID IN (5, 27, 77) THEN CONVERT(NVARCHAR(50), m.kickofftime)
						ELSE m.showtime
					END AS ShowTime,
					b.winlostdate,
					b.betcheck,
					ISNULL(b.transdesc, '') AS TransDesc,
					ISNULL(b.oddsspread, 0) AS OddsSpread,
					0 AS OriginalBetType,
					CASE
						WHEN s.ProductID = 1 THEN ISNULL(b.betdaqid, -1)
						ELSE -1
					END AS BetdaqId,
					ISNULL(b.ExtraInfo, '') AS ExtraInfo,
					'' AS JackpotInfo,
					CASE
						WHEN s.ProductID = 1 THEN ISNULL(b.WalletType, 0)
						ELSE 0
					END AS WalletType,
					CASE
						WHEN s.ProductID = 1 THEN ISNULL(b.RefCode, 0)
						ELSE 0
					END AS RefCode,
					b.currency,
					'' AS SiteId,
					l.LeagueGroupID,
					b.DeviceType
				FROM dbo.bettrans AS b WITH (NOLOCK)
					INNER JOIN @SportBettype AS s ON s.BetType = b.bettype
					INNER JOIN dbo.match AS m WITH (NOLOCK) ON b.matchid = m.matchid
					LEFT JOIN dbo.league AS l WITH (NOLOCK) ON m.leagueid = l.leagueid
				WHERE b.transid = @TransId AND s.EventType = 1

				UNION ALL -- translog metric gaming
				SELECT
					tl.gameid AS BetType,
					tl.translogid AS TransId,
					0 AS BetId,
					tl.translogid AS RefNo,
					m.matchcode,
					'' AS Race,
					m.GlobalShowTime AS EventDate,
					0 AS virtualrate,
					0 AS isShowOTExRate,
					tl.sdiscount,
					CASE
						WHEN tl.mrecommend = -4 THEN 0
						ELSE tl.adiscount
					END,
					CASE
						WHEN tl.recommend IN (-3, -4) THEN 0
						ELSE tl.discount
					END,
					m.homeid,
					m.awayid,
					'' AS settleTime,
					0 AS hdp1,
					0 AS hdp2,
					tl.odds,
					0 AS finalodds,
					0 AS finalodds2,
					CASE
						WHEN tl.gameid IN (801,803,804,805,806) THEN CONVERT(TINYINT, ISNULL(tl.custom1, 0))
						ELSE 0
					END AS OddsType,
					tl.status,
					ISNULL(m.SettlementStatus, 0) AS SettlementStatus,
					'' AS comstatus,
					tl.stake,
					tl.actual_stake,
					tl.transdate,
					'' AS betteam,
					tl.spositiontaking,
					tl.mpositiontaking,
					tl.apositiontaking,
					0 AS SPositionTaking2,
					0 AS MPositionTaking2,
					0 AS APositionTaking2,
					0 AS liveindicator,
					0 AS modds,
					tl.custid,
					0 AS livehomescore,
					0 AS liveawayscore,
					m.finalhomescore,
					m.finalawayscore,
					m.leagueid,
					m.sporttype,
					tl.ip,
					tl.eventID AS MatchId,
					ISNULL(m.isNeutral, CONVERT(BIT,0)) AS IsNeutral,
					0 AS winlost,
					0 AS Commission,
					0 AS scomm,
					0 AS acomm,
					0 AS comm,
					0 AS awinlost,
					0 AS mwinlost,
					0 AS swinlost,
					m.showtime,
					tl.winlostdate,
					'' AS BetCheck,
					ISNULL(tl.transdesc, '') AS TransDesc,
					0 AS OddsSpread,
					0 AS OriginalBetType,
					-1 AS BetdaqId,
					'' AS ExtraInfo,
					'' AS JackpotInfo,
					0 AS WalletType,
					0 AS RefCode,
					tl.currency,
					'' AS SiteId,
					0 AS LeagueGroupID,
					tl.DeviceType
				FROM dbo.translog AS tl WITH (NOLOCK) 
					INNER JOIN @SportBettype AS s ON s.Bettype = tl.gameID
					INNER JOIN dbo.match AS m WITH (NOLOCK) ON tl.eventId = m.matchid
				WHERE tl.translogid = @TransId
					AND tl.statusID IN (0, 1)
					AND s.BetType BETWEEN 801 AND 899

				-- Get more info for BetTrade tickets
				IF EXISTS (SELECT TOP(1) 1 FROM @Data WHERE SportType = 1 AND BetType = 901)
				BEGIN
					UPDATE b
					SET b.Odds = ob.odds,
						b.Stake = ob.stake,
						b.LiveHomeScore = ob.livehomescore,
						b.LiveAwayScore = ob.liveawayscore,
						b.BetId = ob.bettype
					FROM @Data AS b
						INNER JOIN dbo.bettrans AS ob WITH (NOLOCK) ON b.RefNo = ob.transid
					WHERE b.SportType = 1 AND b.BetType = 901
				END

				IF EXISTS (SELECT TOP(1) 1 FROM @Data WHERE SportType = 1 AND BetType = 902)
				BEGIN
					UPDATE b
					SET b.Odds = ob.odds,
						b.Stake = ob.stake,
						b.LiveHomeScore = ob.livehomescore,
						b.LiveAwayScore = ob.liveawayscore,
						b.Comm = ISNULL(cb.awinlost, 0),
						b.BetId = ob.bettype
					FROM @Data AS b
						INNER JOIN dbo.bettrans AS ob WITH (NOLOCK) ON b.RefNo = ob.transid
						LEFT JOIN dbo.bettrans AS cb WITH (NOLOCK)
							ON b.RefNo = cb.refno
							AND cb.bettype = 903
							AND cb.custid = @CustId
							AND cb.winlostdate = @WinLostDate
					WHERE b.SportType = 1 AND b.BetType = 902
				END

				-- Get more info for CashOut tickets
				IF EXISTS (SELECT TOP(1) 1 FROM @Data WHERE BetType = 911)
				BEGIN
					UPDATE b
					SET b.Odds = ob.odds,
						b.LiveIndicator = ob.liveindicator,
						b.LiveHomeScore = ob.livehomescore,
						b.LiveAwayScore = ob.liveawayscore,
						b.OriginalBetType = ob.bettype,
						b.BetdaqId = ob.transid
					FROM @Data AS b
						INNER JOIN dbo.bettrans AS ob WITH (NOLOCK) ON b.RefNo = ob.transid
					WHERE b.BetType = 911
				END

				IF EXISTS (SELECT TOP(1) 1 FROM @Data WHERE BetType = 912)
				BEGIN
					UPDATE b
					SET b.Odds = ob.odds,
						b.LiveIndicator = ob.liveindicator,
						b.LiveHomeScore = ob.livehomescore,
						b.LiveAwayScore = ob.liveawayscore,
						b.OriginalBetType = ob.bettype,
						b.BetdaqId = ob.transid,
						b.Stake = cob.stake,
						b.Comm = ISNULL(cb.AWinLost, 0)
					FROM @Data AS b
						INNER JOIN dbo.bettrans AS cob WITH (NOLOCK) ON b.RefNo = cob.transid
						INNER JOIN dbo.bettrans AS ob WITH (NOLOCK) ON cob.RefNo = ob.transid
						LEFT JOIN dbo.bettrans AS cb WITH (NOLOCK)
							ON b.RefNo = cb.refno
							AND cb.bettype = 913
							AND cb.custid = @CustId
							AND cb.winlostdate = @WinLostDate
					WHERE b.BetType = 912
				END
			END

			-- Bitcoin, Virtual Sports 5, vs6 (EventType = 5)
			IF EXISTS (SELECT TOP(1) 1 FROM @SportBettype WHERE EventType = 5 AND BetType = @BetType)
			BEGIN
				INSERT INTO @Data (
					BetType, TransId, BetId, RefNo, MatchCode, Race, EventDate, VirtualRate, IsShowOTExRate,
					SDiscount, ADiscount, Discount, HomeId, AwayId, SettleTime, Hdp1, Hdp2, Odds, FinalOdds,
					FinalOdds2, OddsType, Status, SettlementStatus, ComStatus, Stake, Actual_Stake, TransDate,
					BetTeam, SPositionTaking, MPositionTaking, APositionTaking, SPositionTaking2, MPositionTaking2,
					APositionTaking2, LiveIndicator, Modds, CustId, LiveHomeScore, LiveAwayScore, FinalHomeScore,
					FinalAwayScore, LeagueId, SportType, Ip, MatchId, IsNeutral, WinLost, Commission, SComm,
					AComm, Comm, AWinLost, MWinLost, SWinLost, ShowTime, WinLostDate, BetCheck, TransDesc,
					OddsSpread, OriginalBetType, BetdaqId, ExtraInfo, JackpotInfo, WalletType, RefCode,
					CurrencyId, SiteId, LeagueGroupId, DeviceType
				)
				SELECT
					vsb.bettype,
					vsb.transid,
					ISNULL(vsb.betid, 0) AS BetId,
					vsb.refno,
					m.matchcode,
					'' AS Race,
					m.EndTime AS EventDate,
					0 AS VirtualRate,
					0 AS IsShowOTExRate,
					vsb.sdiscount,
					CASE
						WHEN vsb.mrecommend = -4 THEN 0
						ELSE vsb.adiscount
					END,
					CASE
						WHEN vsb.recommend IN (-3, -4) THEN 0
						ELSE vsb.discount
					END,
					m.homeid,
					m.awayid,
					ISNULL(vsb.checktime,'') AS SettleTime,
					vsb.hdp1,
					vsb.hdp2,
					vsb.odds,
					0 AS finalodds,
					0 AS finalodds2,
					vsb.OddsType,
					vsb.status AS status,
					0 AS SettlementStatus,
					0 AS comstatus,
					vsb.stake,
					vsb.actual_stake,
					vsb.transdate,
					vsb.betteam,
					vsb.spositiontaking,
					vsb.mpositiontaking,
					vsb.apositiontaking,
					0 AS SPositionTaking2,
					0 AS MPositionTaking2,
					0 AS APositionTaking2,
					vsb.liveindicator,
					vsb.modds,
					vsb.custid,
					vsb.livehomescore,
					vsb.liveawayscore,
					m.finalhomescore,
					m.finalawayscore,
					m.league3rdid,
					m.sporttype,
					vsb.ip,
					vsb.matchid,
					CONVERT(BIT,0) AS IsNeutral,
					(vsb.winlost - vsb.actual_stake) AS winlost,
					vsb.playercomm AS Commission,
					(vsb.scomm - vsb.acomm) AS scomm,
					(vsb.acomm - vsb.comm) AS acomm,
					(vsb.comm - vsb.playercomm) AS comm,
					vsb.awinlost,
					vsb.mwinlost,
					vsb.swinlost,
					CONVERT(NVARCHAR(50), m.StartTime) AS ShowTime,
					vsb.winlostdate,
					vsb.betcheck,
					ISNULL(vsb.transdesc, '') AS TransDesc,
					ISNULL(vsb.oddsspread, 0) AS OddsSpread,
					0 AS OriginalBetType,
					-1 AS BetdaqId,
					ISNULL(vsb.ExtraInfo, '') AS ExtraInfo,
					'' AS JackpotInfo,
					0 AS WalletType,
					0 AS RefCode,
					vsb.currency,
					'' AS SiteId,
					0 AS LeagueGroupID,
					vsb.DeviceType
				FROM dbo.bettrans AS vsb WITH (NOLOCK)
					INNER JOIN @SportBettype AS s ON s.BetType = vsb.bettype
					INNER JOIN dbo.match3rd AS m WITH (NOLOCK) ON vsb.matchid = m.match3rdid
				WHERE vsb.transid = @TransId AND s.EventType = 5

			END

			-- Mix Parlay, System Parlay, Mix Parlay (Betradar Virtual Sports), Mix Parlay (VS4), Mix Parlay (VS5)
			IF @BetType IN (9, 29, 2798, 2799, 10449, 11099)
			BEGIN
				INSERT INTO @Data (
					BetType, TransId, BetId, RefNo, MatchCode, Race, EventDate, VirtualRate, IsShowOTExRate,
					SDiscount, ADiscount, Discount, HomeId, AwayId, SettleTime, Hdp1, Hdp2, Odds, FinalOdds,
					FinalOdds2, OddsType, Status, SettlementStatus, ComStatus, Stake, Actual_Stake, TransDate,
					BetTeam, SPositionTaking, MPositionTaking, APositionTaking, SPositionTaking2, MPositionTaking2,
					APositionTaking2, LiveIndicator, Modds, CustId, LiveHomeScore, LiveAwayScore, FinalHomeScore,
					FinalAwayScore, LeagueId, SportType, Ip, MatchId, IsNeutral, WinLost, Commission, SComm,
					AComm, Comm, AWinLost, MWinLost, SWinLost, ShowTime, WinLostDate, BetCheck, TransDesc,
					OddsSpread, OriginalBetType, BetdaqId, ExtraInfo, JackpotInfo, WalletType, RefCode,
					CurrencyId, SiteId, LeagueGroupId, DeviceType
				)
				SELECT
					bmx.bettype,
					bmx.transid,
					ISNULL(bmx.betid, 0) AS BetId,
					bmx.refno,
					'' AS MatchCode,
					'' AS Race,
					'' AS EventDate,
					0 AS VirtualRate,
					0 AS IsShowOTExRate,
					bmx.sdiscount,
					CASE
						WHEN bmx.mrecommend = -4 THEN 0
						ELSE bmx.adiscount
					END,
					CASE
						WHEN bmx.recommend IN (-3, -4) THEN 0
						ELSE bmx.discount
					END,
					0 AS HomeId,
					0 AS AwayId,
					'' AS SettleTime,
					bmx.hdp1,
					bmx.hdp2,
					bmx.odds,
					0 AS FinalOdds,
					0 AS FinalOdds2,
					0 AS OddsType,
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
					CASE WHEN bmx.comstatus = '1' THEN 1 ELSE 0 END AS comstatus,
					bmx.stake,
					bmx.actual_stake,
					bmx.transdate,
					bmx.betteam,
					bmx.spositiontaking,
					bmx.mpositiontaking,
					bmx.apositiontaking,
					0 AS SPositionTaking2,
					0 AS MPositionTaking2,
					0 AS APositionTaking2,
					0 AS LiveIndicator,
					bmx.modds,
					bmx.custid,
					bmx.livehomescore,
					bmx.liveawayscore,
					0 AS FinalHomeScore,
					0 AS FinalAwayScore,
					0 AS LeagueId,
					0 AS SportType,
					bmx.ip,
					0 AS MatchId,
					CONVERT(BIT, 0) AS IsNeutral,
					(bmx.winlost - bmx.actual_stake) AS WinLost,
					bmx.playercomm AS Commission,
					(bmx.scomm - bmx.acomm) AS SComm,
					(bmx.acomm - bmx.comm) AS AComm,
					(bmx.comm - bmx.playercomm) AS Comm,
					bmx.awinlost,
					bmx.mwinlost,
					bmx.swinlost,
					'' AS ShowTime,
					bmx.winlostdate,
					bmx.betcheck,
					IIF(bmx.bettype = 29 AND bmx.oddsspread = 3, ISNULL(bmx.transdesc, ''), '') AS TransDesc,
					ISNULL(bmx.oddsspread, 0) AS OddsSpread,
					0 AS OriginalBetType,
					-1 AS BetdaqId,
					bmx.ExtraInfo AS ExtraInfo,
					'' AS JackpotInfo,
					0 AS WalletType,
					0 AS RefCode,
					bmx.currency,
					'' AS SiteId,
					0 AS LeagueGroupID,
					bmx.DeviceType
				FROM dbo.bettrans AS bmx WITH (NOLOCK)
				WHERE bmx.transid = @TransId AND bmx.bettype IN (9, 29, 2798, 2799, 10449, 11099)
			END

			-- Outright
			IF @BetType = 10
			BEGIN
				INSERT INTO @Data (
					BetType, TransId, BetId, RefNo, MatchCode, Race, EventDate, VirtualRate, IsShowOTExRate,
					SDiscount, ADiscount, Discount, HomeId, AwayId, SettleTime, Hdp1, Hdp2, Odds, FinalOdds,
					FinalOdds2, OddsType, Status, SettlementStatus, ComStatus, Stake, Actual_Stake, TransDate,
					BetTeam, SPositionTaking, MPositionTaking, APositionTaking, SPositionTaking2, MPositionTaking2,
					APositionTaking2, LiveIndicator, Modds, CustId, LiveHomeScore, LiveAwayScore, FinalHomeScore,
					FinalAwayScore, LeagueId, SportType, Ip, MatchId, IsNeutral, WinLost, Commission, SComm,
					AComm, Comm, AWinLost, MWinLost, SWinLost, ShowTime, WinLostDate, BetCheck, TransDesc,
					OddsSpread, OriginalBetType, BetdaqId, ExtraInfo, JackpotInfo, WalletType, RefCode,
					CurrencyId, SiteId, LeagueGroupId, DeviceType
				)
				SELECT
					bor.bettype,
					bor.transid,
					ISNULL(bor.betid, 0) AS BetId,
					bor.refno,
					odds.matchcode,
					odds.groupmatch AS Race,
					odds.eventdate,
					0 AS VirtualRate,
					0 AS IsShowOTExRate,
					bor.sdiscount,
					CASE
						WHEN bor.mrecommend = -4 THEN 0
						ELSE bor.adiscount
					END,
					CASE
						WHEN bor.recommend IN (-3, -4) THEN 0
						ELSE bor.discount
					END,
					0 AS Homeid,
					odds.teamid AS awayid,
					'' AS SettleTime,
					bor.hdp1,
					bor.hdp2,
					bor.odds,
					0 AS FinalOdds,
					0 AS FinalOdds2,
					bor.oddstype AS OddsType,
					bor.status,
					0 AS SettlementStatus,
					CASE WHEN bor.comstatus = '1' THEN 1 ELSE 0 END AS comstatus,
					bor.stake,
					bor.actual_stake,
					bor.transdate,
					bor.betteam,
					bor.spositiontaking,
					bor.mpositiontaking,
					bor.apositiontaking,
					0 AS SPositionTaking2,
					0 AS MPositionTaking2,
					0 AS APositionTaking2,
					bor.liveindicator,
					bor.modds,
					bor.custid,
					bor.livehomescore,
					bor.liveawayscore,
					0 AS FinalHomeScore,
					0 AS FinalAwayScore,
					odds.leagueid,
					l.sporttype,
					bor.ip ,
					bor.matchid,
					CONVERT(BIT,0) AS IsNeutral,
					(bor.winlost - bor.actual_stake) AS winlost,
					bor.playercomm AS Commission,
					(bor.scomm - bor.acomm) AS scomm,
					(bor.acomm - bor.comm) AS acomm,
					(bor.comm - bor.playercomm) AS comm,
					bor.awinlost,
					bor.mwinlost,
					bor.swinlost,
					'' AS showtime,
					bor.winlostdate,
					bor.BetCheck,
						'' AS TransDesc,
					0 AS OddsSpread,
					0 AS OriginalBetType,
					-1 AS BetdaqId,
					'' AS ExtraInfo,
					'' AS JackpotInfo,
					0 AS WalletType,
					0 AS RefCode,
					bor.currency,
					'' AS SiteId,
					0 AS LeagueGroupID,
					bor.DeviceType
				FROM dbo.bettrans AS bor WITH (NOLOCK)
					INNER JOIN dbo.outright AS odds WITH (NOLOCK) ON bor.matchid = odds.orid
					INNER JOIN dbo.league AS l WITH (NOLOCK) ON odds.leagueid = l.leagueid
				WHERE bor.transid = @TransId AND bor.bettype = 10
			END

			-- Keno, NG2, Lottery, NPH Promotion, Virtual Games, Table Games, Indo 4D, BBIN, Leap Gaming Virtual Sports, Happy 5 Linked Games(Number Game), Sports Lottery
			-- Player Tips, Saba Coins
			IF EXISTS (SELECT TOP(1) 1 FROM @SportBettype
						WHERE BetType = @BetType
							AND (ProductID IN (8, 23, 28, 37, 38, 40, 43, 47, 49, 63, 74, 81) OR (ProductID = 3 AND EventType = 0)))
			BEGIN
				INSERT INTO @Data (
					BetType, TransId, BetId, RefNo, MatchCode, Race, EventDate, VirtualRate, IsShowOTExRate,
					SDiscount, ADiscount, Discount, HomeId, AwayId, SettleTime, Hdp1, Hdp2, Odds, FinalOdds,
					FinalOdds2, OddsType, Status, SettlementStatus, ComStatus, Stake, Actual_Stake, TransDate,
					BetTeam, SPositionTaking, MPositionTaking, APositionTaking, SPositionTaking2, MPositionTaking2,
					APositionTaking2, LiveIndicator, Modds, CustId, LiveHomeScore, LiveAwayScore, FinalHomeScore,
					FinalAwayScore, LeagueId, SportType, Ip, MatchId, IsNeutral, WinLost, Commission, SComm,
					AComm, Comm, AWinLost, MWinLost, SWinLost, ShowTime, WinLostDate, BetCheck, TransDesc,
					OddsSpread, OriginalBetType, BetdaqId, ExtraInfo, JackpotInfo, WalletType, RefCode,
					CurrencyId, SiteId, LeagueGroupId, DeviceType
				)
				SELECT
					btp.bettype,
					btp.transid,
					ISNULL(btp.betid, 0) AS BetId,
					btp.refno,
					'' AS matchcode,
					'' AS Race,
					'' AS eventdate,
					0 AS virtualrate,
					0 AS isShowOTExRate,
					btp.sdiscount,
					CASE
						WHEN btp.mrecommend = -4 THEN 0
						ELSE btp.adiscount
					END,
					CASE
						WHEN btp.recommend IN (-3, -4) THEN 0
						ELSE btp.discount
					END,
					0 AS homeid,
					0 AS awayid,
					'' AS settleTime,
					CASE
						WHEN s.ProductId = 23 THEN btp.hdp1
						ELSE 0
					END AS hdp1,
					CASE
						WHEN s.ProductId = 23 THEN btp.hdp2
						ELSE 0
					END AS hdp2,
					CASE
						WHEN s.ProductID IN (3, 8, 23, 28, 38, 40, 43, 49, 63) THEN btp.odds
						ELSE 0
					END AS odds,
					0 AS finalodds,
					0 AS finalodds2,
					0 AS OddsType,
					CASE
						WHEN s.ProductID = 40 AND btp.status = 'Won' AND btp.modds = 0.25 THEN 'Half Won'
						WHEN s.ProductID = 40 AND btp.status = 'Lose' AND btp.modds = -0.25 THEN 'Half Lose'
						ELSE btp.status
					END AS status,
					0 AS SettlementStatus,
					'' AS comstatus,
					btp.stake,
					btp.actual_stake,
					btp.transdate,
					'' AS betteam,
					btp.spositiontaking,
					btp.mpositiontaking,
					btp.apositiontaking,
					0 AS SPositionTaking2,
					0 AS MPositionTaking2,
					0 AS APositionTaking2,
					0 AS liveindicator,
					0 AS modds,
					btp.custid,
					CASE
						WHEN s.ProductId = 23 THEN btp.livehomescore
						ELSE 0
					END AS livehomescore,
					0 AS LiveAwayScore,
					0,
					0,
					0 AS leagueid,
					CASE
						WHEN s.ProductID = 8 THEN 202
						WHEN s.ProductID = 23 AND s.Bettype BETWEEN 2501 AND 2539 THEN 213
						WHEN s.ProductID = 23 AND s.Bettype BETWEEN 2541 AND 2579 THEN 214
						WHEN s.ProductID = 23 AND s.Bettype BETWEEN 2581 AND 2619 THEN 215
						WHEN s.ProductID = 23 AND s.Bettype BETWEEN 2621 AND 2659 THEN 216
						WHEN s.ProductID = 23 AND s.Bettype BETWEEN 2681 AND 2699 THEN 218
						WHEN s.ProductID = 28 THEN 220
						WHEN s.ProductID IN (3, 37, 38, 40, 43, 47, 49, 63, 74, 81) THEN btp.matchid
						ELSE 0
					END AS SportType,
					btp.ip,
					CASE
						WHEN s.ProductID = 23 THEN btp.betdaqid
						WHEN s.ProductID = 74 THEN ISNULL(CAST(('<xml>' + btp.ExtraInfo + '</xml>') AS XML).value('data(/xml/p74/@m)[1]','INT'), 0)
						ELSE 0
					END AS MatchId,
					CONVERT(BIT, 0) AS IsNeutral,
					(btp.winlost - btp.actual_stake) AS winlost,
					btp.playercomm AS Commission,
					(btp.scomm - btp.acomm) AS scomm,
					(btp.acomm - btp.comm) AS acomm,
					(btp.comm - btp.playercomm) AS comm,
					btp.awinlost,
					btp.mwinlost,
					btp.swinlost,
					'' AS showtime,
					btp.winlostdate,
					CASE
						WHEN s.ProductID IN (3, 38, 63) THEN btp.betcheck
						WHEN s.ProductId = 8 THEN ISNULL(btp.comstatus, '')
						ELSE ''
					END AS BetCheck,
					CASE
						WHEN s.ProductID IN (3, 8, 23, 28, 38, 40, 43, 49, 63) THEN btp.transdesc
						ELSE ''
					END AS TransDesc,
					0 AS OddsSpread,
					0 AS OriginalBetType,
					-1 AS BetdaqId,
					ISNULL(btp.ExtraInfo, '') AS ExtraInfo,
					'' AS JackpotInfo,
					0 AS WalletType,
					0 AS RefCode,
					btp.currency,
					CASE 
						WHEN s.ProductId = 3 AND s.EventType = 0 THEN CONVERT(VARCHAR(20), btp.betdaqid)
						WHEN s.ProductId IN (38, 63) THEN CONVERT(VARCHAR(20), btp.betdaqid)
						ELSE '' 
					END AS SiteId,
					0 AS LeagueGroupID,
					btp.DeviceType
				FROM dbo.bettrans AS btp WITH (NOLOCK)
					INNER JOIN @SportBettype AS s ON s.Bettype = btp.bettype
				WHERE btp.transid = @TransId
					AND (s.ProductId IN (8, 23, 28, 37, 38, 40, 43, 47, 49, 63, 74, 81)
							OR (s.ProductId = 3 AND s.EventType = 0))

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

			-- Virtual Horse Racing, VS 2 Racing, VS7
			IF EXISTS (SELECT TOP(1) 1 FROM @SportBettype WHERE ProductID IN (5, 27, 106) AND EventType = 3 AND BetType = @BetType)
			BEGIN
				INSERT INTO @Data (
					BetType, TransId, BetId, RefNo, MatchCode, Race, EventDate, VirtualRate, IsShowOTExRate,
					SDiscount, ADiscount, Discount, HomeId, AwayId, SettleTime, Hdp1, Hdp2, Odds, FinalOdds,
					FinalOdds2, OddsType, Status, SettlementStatus, ComStatus, Stake, Actual_Stake, TransDate,
					BetTeam, SPositionTaking, MPositionTaking, APositionTaking, SPositionTaking2, MPositionTaking2,
					APositionTaking2, LiveIndicator, Modds, CustId, LiveHomeScore, LiveAwayScore, FinalHomeScore,
					FinalAwayScore, LeagueId, SportType, Ip, MatchId, IsNeutral, WinLost, Commission, SComm,
					AComm, Comm, AWinLost, MWinLost, SWinLost, ShowTime, WinLostDate, BetCheck, TransDesc,
					OddsSpread, OriginalBetType, BetdaqId, ExtraInfo, JackpotInfo, WalletType, RefCode,
					CurrencyId, SiteId, LeagueGroupId, DeviceType
				)
				SELECT
					bvh.bettype,
					bvh.transid,
					0 AS BetId,
					bvh.refno,
					'' AS MatchCode,
					bvh.oddsid AS Race,
					'' eventdate,
					0 AS virtualrate,
					0 AS isShowOTExRate,
					bvh.sdiscount,
					CASE
						WHEN bvh.mrecommend = -4 THEN 0
						ELSE bvh.adiscount
					END,
					CASE
						WHEN bvh.recommend IN (-3, -4) THEN 0
						ELSE bvh.discount
					END,
					0 AS HomeId,
					0 AS awayID,
					'' AS SettleTime,
					bvh.hdp1,
					bvh.hdp2,
					bvh.odds,
					0 AS finalodds,
					0 AS finalodds2,
					bvh.OddsType,
					bvh.status,
					0 AS SettlementStatus,
					CASE WHEN bvh.comstatus = '1' THEN 1 ELSE 0 END AS comstatus,
					bvh.stake,
					bvh.actual_stake,
					bvh.transdate,
					bvh.betteam AS betteam,
					CASE WHEN bvh.bettype = 1233 THEN bm.spositiontaking ELSE bvh.spositiontaking END,
					CASE WHEN bvh.bettype = 1233 THEN bm.mpositiontaking ELSE bvh.mpositiontaking END,
					CASE WHEN bvh.bettype = 1233 THEN bm.apositiontaking ELSE bvh.apositiontaking END,
					CASE WHEN bvh.bettype = 1233 THEN bm.spositiontaking2 ELSE 0 END,
					CASE WHEN bvh.bettype = 1233 THEN bm.mpositiontaking2 ELSE 0 END,
					CASE WHEN bvh.bettype = 1233 THEN bm.apositiontaking2 ELSE 0 END,
					0 liveindicator,
					bvh.modds,
					bvh.custid,
					bvh.livehomescore,
					bvh.liveawayscore,
					0 finalhomescore,
					0 finalawayscore,
					r.leagueid,
					r.sporttype,
					bvh.ip,
					bvh.matchid,
					CONVERT (BIT, 0) AS IsNeutral,
					(bvh.winlost - bvh.actual_stake) AS winlost,
					bvh.playercomm AS Commission,
					(bvh.scomm - bvh.acomm) AS scomm,
					(bvh.acomm - bvh.comm) AS acomm,
					(bvh.comm - bvh.playercomm) AS comm,
					bvh.awinlost,
					bvh.mwinlost,
					bvh.swinlost,
					'' AS showtime,
					bvh.winlostdate,
					bvh.BetCheck,
					bvh.transdesc AS TransDesc,
					0 AS OddsSpread,
					0 AS OriginalBetType,
					-1 AS BetdaqId,
					bvh.ExtraInfo,
					'' AS JackpotInfo,
					0 AS WalletType,
					0 AS RefCode,
					bvh.currency,
					'' AS SiteId,
					0 AS LeagueGroupID,
					bvh.DeviceType
				FROM dbo.bettrans AS bvh WITH (NOLOCK) 
					INNER JOIN dbo.VSRaceInfo AS r WITH (NOLOCK) ON r.EventID = bvh.matchid
					INNER JOIN @SportBettype AS s ON s.BetType = bvh.BetType 
					LEFT JOIN (
						SELECT
							t.refno,
							t.apositiontaking,
							t.mpositiontaking,
							t.spositiontaking,
							f.apositiontaking AS APositionTaking2,
							f.mpositiontaking AS MPositionTaking2,
							f.spositiontaking AS spositiontaking2
						FROM dbo.bettransm AS t WITH (NOLOCK)
							INNER JOIN dbo.bettransm AS f WITH (NOLOCK) ON t.refno = f.refno
						WHERE t.bettype = 1231 AND f.bettype = 1232 
						) bm ON bvh.refno = bm.refno
				WHERE bvh.transid = @TransId
					AND s.EventType = 3
			END

			-- Keno, Lottery, Virtual Games, Table Games, Indo 4D, Leap Gaming Virtual Sports, Happy 5 Linked Games(Number Game), Sports Lottery (translog)
			IF EXISTS (SELECT TOP(1) 1 FROM @SportBettype
						WHERE (ProductID IN (8, 28, 38, 40, 43, 49, 63) OR (ProductID = 3 AND EventType = 0))
							AND Bettype = @BetType)
			BEGIN
				INSERT INTO @Data (
					BetType, TransId, BetId, RefNo, MatchCode, Race, EventDate, VirtualRate, IsShowOTExRate,
					SDiscount, ADiscount, Discount, HomeId, AwayId, SettleTime, Hdp1, Hdp2, Odds, FinalOdds,
					FinalOdds2, OddsType, Status, SettlementStatus, ComStatus, Stake, Actual_Stake, TransDate,
					BetTeam, SPositionTaking, MPositionTaking, APositionTaking, SPositionTaking2, MPositionTaking2,
					APositionTaking2, LiveIndicator, Modds, CustId, LiveHomeScore, LiveAwayScore, FinalHomeScore,
					FinalAwayScore, LeagueId, SportType, Ip, MatchId, IsNeutral, WinLost, Commission, SComm,
					AComm, Comm, AWinLost, MWinLost, SWinLost, ShowTime, WinLostDate, BetCheck, TransDesc,
					OddsSpread, OriginalBetType, BetdaqId, ExtraInfo, JackpotInfo, WalletType, RefCode,
					CurrencyId, SiteId, LeagueGroupId, DeviceType
				)
				SELECT
					bkl.gameid AS BetType,
					bkl.translogid AS TransId,
					0 AS BetId,
					bkl.translogid AS RefNo,
					'' AS matchcode,
					'' AS Race,
					'' AS eventdate,
					0,
					0,
					bkl.sdiscount,
					bkl.adiscount,
					bkl.discount,
					0 AS homeid,
					0 AS awayid,
					'' AS settleTime,
					0 AS hdp1,
					0 AS hdp2,
					CASE
						WHEN s.ProductID IN (3, 8, 28, 38, 40, 43, 49, 63) THEN bkl.odds
						ELSE 0
					END AS odds,
					0 AS finalodds,
					0 AS finalodds2,
					0 AS OddsType,
					bkl.status,
					0 AS SettlementStatus,
					0 AS comstatus,
					bkl.stake,
					bkl.actual_stake,
					bkl.transdate,
					'' AS betteam,
					bkl.spositiontaking,
					bkl.mpositiontaking,
					bkl.apositiontaking,
					0 AS SPositionTaking2,
					0 AS MPositionTaking2,
					0 AS APositionTaking2,
					0 AS liveindicator,
					0 AS modds,
					bkl.custid,
					0 AS livehomescore,
					0 AS liveawayscore,
					0 AS finalhomescore,
					0 AS finalawayscore,
					0 AS leagueid,
					CASE
						WHEN s.ProductID = 8 THEN 202
						WHEN s.ProductID = 28 THEN 220
						WHEN s.ProductID IN (3, 38, 40, 43, 49, 63) THEN bkl.productID
						ELSE 0
					END AS SportType,
					bkl.ip,
					0 AS MatchId,
					CONVERT(BIT, 0) AS IsNeutral,
					(-bkl.actual_stake) AS winlost,
					0 AS Commission,
					0,
					0,
					0,
					0,
					0,
					0,
					'' AS showtime,
					bkl.winlostdate,
					CASE
						WHEN s.ProductID IN (3) THEN bkl.GameID3rd
						WHEN s.ProductID IN (38, 63) THEN bkl.TranId3rd
						WHEN s.ProductId = 8 THEN ISNULL(bkl.custom2, '')
						WHEN s.ProductId = 49 THEN ISNULL(bkl.custom1, '')
						ELSE ''
					END AS BetCheck,
					CASE
						WHEN s.ProductID IN (3, 8, 28, 38, 40, 43, 49, 63) THEN ISNULL(bkl.transdesc, '')
						ELSE ''
					END AS TransDesc,
					0 AS OddsSpread,
					0 AS OriginalBetType,
					-1 AS BetdaqId,
					'' AS ExtraInfo,
					'' AS JackpotInfo,
					0 AS WalletType,
					0 AS RefCode,
					bkl.currency,
					bkl.SiteId,
					0 AS LeagueGroupID,
					bkl.DeviceType
				FROM dbo.translog AS bkl WITH (NOLOCK)
					INNER JOIN @SportBettype AS s ON s.Bettype = bkl.gameID
				WHERE bkl.translogid = @TransId
					AND bkl.statusID IN (0, 1)
					AND (s.ProductID IN (8, 28, 38, 40, 43, 49, 63)
							OR (s.ProductID = 3 AND s.EventType = 0))
			END

			-- RNG Casino Single Wallet, Macau Games, Pragmatic Casino, Card Club, Spadegaming, Saba.club, RNG War, PG Soft, Joker, MaxGame, CG, VGaming
			-- Habanero, AdvantPlay, AdvantPlay Mini, SEAL Entertainment, MG RNG Casino, Jili, Live22, UU Slots, Saba xD
			IF EXISTS (	SELECT TOP(1) 1 FROM @SportBettype
						WHERE Bettype = @BetType
							AND (ProductID IN (22, 32, 34, 36, 42, 50, 55, 56, 60, 61, 62, 66, 67, 68, 72, 73, 75, 78, 79, 86)
								OR (ProductID = 6 AND SubProduct <> '')
								OR RefTable = 1))
			BEGIN
				IF @WinLostDate >= DATEADD(DAY, DATEDIFF(DAY, 1, GETDATE()), 0)		-- yesterday and later
				BEGIN
					-- Yesterday and later running ticket
					INSERT INTO @Data (
						BetType, TransId, BetId, RefNo, MatchCode, Race, EventDate, VirtualRate, IsShowOTExRate,
						SDiscount, ADiscount, Discount, HomeId, AwayId, SettleTime, Hdp1, Hdp2, Odds, FinalOdds,
						FinalOdds2, OddsType, Status, SettlementStatus, ComStatus, Stake, Actual_Stake, TransDate,
						BetTeam, SPositionTaking, MPositionTaking, APositionTaking, SPositionTaking2, MPositionTaking2,
						APositionTaking2, LiveIndicator, Modds, CustId, LiveHomeScore, LiveAwayScore, FinalHomeScore,
						FinalAwayScore, LeagueId, SportType, Ip, MatchId, IsNeutral, WinLost, Commission, SComm,
						AComm, Comm, AWinLost, MWinLost, SWinLost, ShowTime, WinLostDate, BetCheck, TransDesc,
						OddsSpread, OriginalBetType, BetdaqId, ExtraInfo, JackpotInfo, WalletType, RefCode,
						CurrencyId, SiteId, LeagueGroupId, DeviceType
					)
					SELECT
						b.bettype,
						b.transid,
						ISNULL(b.BetID, 0) AS BetId,
						b.refno,
						'' AS matchcode,
						'' AS Race,
						'' AS eventdate,
						0 AS virtualrate,
						0 AS isShowOTExRate,
						AVG(brng.sdiscount) AS sdiscount,
						CASE
							WHEN b.mrecommend = -4 THEN 0
							ELSE AVG(brng.adiscount)
						END AS adiscount,
						CASE
							WHEN b.recommend IN (-3, -4) THEN 0
							ELSE AVG(brng.discount)
						END AS discount,
						0 AS homeid,
						0 AS awayid,
						'' AS settleTime,
						0 AS hdp1,
						0 AS hdp2,
						0 AS odds,
						0 AS finalodds,
						0 AS finalodds2,
						0 AS OddsType,
						'Running' AS Status,
						0 AS SettlementStatus,
						CASE WHEN b.comstatus = '1' THEN 1 ELSE 0 END AS comstatus,
						SUM(brng.stake) AS stake,
						SUM(brng.actual_stake) AS actual_stake,
						b.transdate,
						'' AS betteam,
						AVG(brng.spositiontaking) AS spositiontaking,
						AVG(brng.mpositiontaking) AS mpositiontaking,
						AVG(brng.apositiontaking) AS apositiontaking,
						0 AS SPositionTaking2,
						0 AS MPositionTaking2,
						0 AS APositionTaking2,
						0 AS liveindicator,
						0 AS modds,
						b.custid,
						0 AS livehomescore,
						0 AS liveawayscore,
						0,
						0,
						0 AS leagueid,
						CASE
							WHEN s.ProductID = 22 THEN 212
							WHEN s.ProductID = 32 THEN 248
							ELSE b.matchid
						END AS Sporttype,
						b.ip,
						0 AS MatchId,
						CONVERT(BIT, 0) AS IsNeutral,
						0 AS winlost,
						0 AS Commission,
						0 AS scomm,
						0 AS acomm,
						0 AS comm,
						0 AS awinlost,
						0 AS mwinlost,
						0 AS swinlost,
						'' AS showtime,
						b.winlostdate,
						'' AS BetCheck,
						CASE
							WHEN s.ProductID IN (6, 22, 32, 34, 36, 55, 56, 61, 62, 67, 68, 72) THEN b.transdesc
							ELSE ''
						END AS TransDesc,
						0 AS OddsSpread,
						0 AS OriginalBetType,
						-1 AS BetdaqId,
						'' AS ExtraInfo,
						'' AS JackpotInfo,
						0 AS WalletType,
						0 AS RefCode,
						0 AS CurrencyId,
						'' AS SiteId,
						0 AS LeagueGroupID,
						b.DeviceType
					FROM dbo.bettransRnG AS brng WITH (NOLOCK)
						INNER JOIN dbo.bettrans AS b WITH (NOLOCK) ON brng.RefNo = b.transid
						INNER JOIN @SportBettype AS s ON s.Bettype = b.bettype
					WHERE b.transid = @TransId
						AND (s.ProductId IN (22, 32, 34, 36, 42, 50, 55, 56, 60, 61, 62, 66, 67, 68, 72, 73, 75, 78, 79, 86)
							OR (s.ProductId = 6 AND s.SubProduct <> '')
							OR s.RefTable = 1)
						AND brng.statusid IN (0, 1)
					GROUP BY
						b.transid,
						ISNULL(b.betid, 0),
						b.bettype,
						b.refno,
						b.transdate,
						b.winlostdate,
						b.custid,
						b.ip,
						b.matchid,
						b.comstatus,
						b.transdesc,
						s.ProductID,
						b.DeviceType,
						b.mrecommend,
						b.recommend

					-- Yesterday and later settled ticket
					UNION ALL
					SELECT
						byt.bettype,
						byt.transid,
						ISNULL(byt.betid, 0) AS BetId,
						byt.refno,
						'' AS matchcode,
						'' AS Race,
						'' AS eventdate,
						0 AS virtualrate,
						0 AS isShowOTExRate,
						AVG(brng.sdiscount) AS sdiscount,
						CASE
							WHEN byt.mrecommend = -4 THEN 0
							ELSE AVG(brng.adiscount)
						END AS adiscount,
						CASE
							WHEN byt.recommend IN (-3, -4) THEN 0
							ELSE AVG(brng.discount)
						END AS discount,
						0 AS homeid,
						0 AS awayid,
						'' AS settleTime,
						0 AS hdp1,
						0 AS hdp2,
						CASE
							WHEN pj.ProductId IS NOT NULL
								THEN ISNULL(AVG(CASE WHEN brng.statusID IN (111, 112, 113) THEN brng.ContributionRate END), 0)
							ELSE 0
						END AS Odds,
						0 AS finalodds,
						0 AS finalodds2,
						0 AS OddsType,
						CASE 
							WHEN SUM(brng.winlost - brng.actual_stake) > 0 THEN 'Won'
							WHEN SUM(brng.winlost - brng.actual_stake) < 0 THEN 'Lose'
							ELSE 'Draw'
						END AS Status,
						0 AS SettlementStatus,
						CASE WHEN byt.comstatus = '1' THEN 1 ELSE 0 END AS comstatus,
						SUM(brng.stake) AS stake,
						SUM(brng.actual_stake) AS actual_stake,
						byt.transdate,
						'' AS betteam,
						AVG(brng.spositiontaking) AS spositiontaking,
						AVG(brng.mpositiontaking) AS mpositiontaking,
						AVG(brng.apositiontaking) AS apositiontaking,
						0 AS SPositionTaking2,
						0 AS MPositionTaking2,
						0 AS APositionTaking2,
						0 AS liveindicator,
						0 AS modds,
						byt.custid,
						0 AS livehomescore,
						0 AS liveawayscore,
						0,
						0,
						0 AS leagueid,
						CASE
							WHEN s.ProductID = 22 THEN 212
							WHEN s.ProductID = 32 THEN 248
							ELSE byt.matchid
						END AS Sporttype,
						byt.ip,
						0 AS MatchId,
						CONVERT(BIT, 0) AS IsNeutral,
						SUM(brng.winlost - brng.actual_stake) AS winlost,
						SUM(brng.playercomm) AS Commission,
						SUM(brng.scomm - brng.acomm) AS scomm,
						SUM(brng.acomm - brng.comm) AS acomm,
						SUM(brng.comm - brng.playercomm) AS comm,
						SUM(brng.awinlost) AS awinlost,
						SUM(brng.mwinlost) AS mwinlost,
						SUM(brng.swinlost) AS swinlost,
						'' AS showtime,
						byt.winlostdate,
						'' AS BetCheck,
						CASE
							WHEN s.ProductID IN (6, 22, 32, 34, 36, 55, 56, 61, 62, 67, 68, 72) THEN byt.transdesc
							ELSE ''
						END AS TransDesc,
						CASE
							WHEN pj.ProductId IS NOT NULL THEN ISNULL(SUM(brng.BetStake), 0)
							ELSE 0
						END AS OddsSpread,
						0 AS OriginalBetType,
						-1 AS BetdaqId,
						'' AS ExtraInfo,
						'' AS JackpotInfo,
						0 AS WalletType,
						0 AS RefCode,
						0 AS CurrencyId,
						'' AS SiteId,
						0 AS LeagueGroupID,
						byt.DeviceType
					FROM dbo.bettransRnG AS brng WITH (NOLOCK)
						INNER JOIN dbo.bettrans AS byt WITH (NOLOCK) ON brng.RefNo = byt.transid
						INNER JOIN @SportBettype AS s ON s.Bettype = byt.bettype
						LEFT JOIN @ProductJackpot AS pj ON s.ProductId = pj.ProductId
					WHERE byt.transid = @TransId
						AND (s.ProductId IN (22, 32, 34, 36, 42, 50, 55, 56, 60, 61, 62, 66, 67, 68, 72, 73, 75, 78, 79, 86)
							OR (s.ProductId = 6 AND s.SubProduct <> '')
							OR s.RefTable = 1)
						AND brng.statusid NOT IN (0, 1)
					GROUP BY
						byt.transid,
						pj.ProductId,
						ISNULL(byt.betid, 0),
						byt.bettype,
						byt.refno,
						byt.transdate,
						byt.winlostdate,
						byt.custid,
						byt.ip,
						byt.matchid,
						byt.comstatus,
						byt.transdesc,
						s.ProductID,
						byt.DeviceType,
						byt.mrecommend,
						byt.recommend
				END
				ELSE
				BEGIN
					-- Before yesterday settled ticket
					INSERT INTO @Data (
						BetType, TransId, BetId, RefNo, MatchCode, Race, EventDate, VirtualRate, IsShowOTExRate,
						SDiscount, ADiscount, Discount, HomeId, AwayId, SettleTime, Hdp1, Hdp2, Odds, FinalOdds,
						FinalOdds2, OddsType, Status, SettlementStatus, ComStatus, Stake, Actual_Stake, TransDate,
						BetTeam, SPositionTaking, MPositionTaking, APositionTaking, SPositionTaking2, MPositionTaking2,
						APositionTaking2, LiveIndicator, Modds, CustId, LiveHomeScore, LiveAwayScore, FinalHomeScore,
						FinalAwayScore, LeagueId, SportType, Ip, MatchId, IsNeutral, WinLost, Commission, SComm,
						AComm, Comm, AWinLost, MWinLost, SWinLost, ShowTime, WinLostDate, BetCheck, TransDesc,
						OddsSpread, OriginalBetType, BetdaqId, ExtraInfo, JackpotInfo, WalletType, RefCode,
						CurrencyId, SiteId, LeagueGroupId, DeviceType
					)
					SELECT
						bby.bettype,
						bby.transid,
						ISNULL(bby.betid, 0) AS BetId,
						bby.refno,
						'' AS matchcode,
						'' AS Race,
						'' AS eventdate,
						0 AS virtualrate,
						0 AS isShowOTExRate,
						bby.sdiscount,
						bby.adiscount,
						bby.discount,
						0 AS homeid,
						0 AS awayid,
						'' AS settleTime,
						0 AS hdp1,
						0 AS hdp2,
						CASE
							WHEN pj.ProductId IS NOT NULL THEN bby.odds
							ELSE 0
						END AS Odds,
						0 AS finalodds,
						0 AS finalodds2,
						0 AS OddsType,
						bby.status,
						0 AS SettlementStatus,
						CASE WHEN bby.comstatus = '1' THEN 1 ELSE 0 END AS comstatus,
						bby.stake,
						bby.actual_stake,
						bby.transdate,
						'' AS betteam,
						bby.spositiontaking,
						bby.mpositiontaking,
						bby.apositiontaking,
						0 AS SPositionTaking2,
						0 AS MPositionTaking2,
						0 AS APositionTaking2,
						0 AS liveindicator,
						0 AS modds,
						bby.custid,
						0 AS livehomescore,
						0 AS liveawayscore,
						0,
						0,
						0 AS leagueid,
						CASE
							WHEN s.ProductID = 22 THEN 212
							WHEN s.ProductID = 32 THEN 248
							ELSE bby.matchid
						END AS Sporttype,
						bby.ip,
						0 AS MatchId,
						CONVERT(BIT, 0) AS IsNeutral,
						(bby.winlost - bby.actual_stake) AS winlost,
						bby.playercomm AS Commission,
						(bby.scomm - bby.acomm) AS scomm,
						(bby.acomm - bby.comm) AS acomm,
						(bby.comm - bby.playercomm) AS comm,
						bby.awinlost,
						bby.mwinlost,
						bby.swinlost,
						'' AS showtime,
						bby.winlostdate,
						'' AS BetCheck,
						CASE
							WHEN s.ProductID IN (6, 22, 32, 34, 36, 55, 56, 61, 62, 67, 68, 72) THEN bby.transdesc
							ELSE ''
						END AS TransDesc,
						CASE
							WHEN pj.ProductId IS NOT NULL THEN ISNULL(bby.oddsspread, 0)
							ELSE 0
						END AS OddsSpread,
						0 AS OriginalBetType,
						-1 AS BetdaqId,
						'' AS ExtraInfo,
						'' AS JackpotInfo,
						0 AS WalletType,
						0 AS RefCode,
						bby.currency,
						'' AS SiteId,
						0 AS LeagueGroupID,
						bby.DeviceType
					FROM dbo.bettrans AS bby WITH (NOLOCK)
						INNER JOIN @SportBettype AS s ON s.Bettype = bby.bettype
						LEFT JOIN @ProductJackpot AS pj ON s.ProductId = pj.ProductId
					WHERE bby.transid = @TransId
						AND (s.ProductId IN (22, 32, 34, 36, 42, 50, 55, 56, 60, 61, 62, 66, 67, 68, 72, 73, 75, 78, 79, 86)
							OR (s.ProductId = 6 AND s.SubProduct <> '')
							OR RefTable = 1)
				END
			END

			-- AG Casino, AllBet, SA Gaming, Sexy Gaming, IBCBet Live Casino, ION, WM, Big Gaming, PP Live Casino, FGG, YeeBet, WE, ON Casino
			IF EXISTS (SELECT TOP(1) 1 FROM @SportBettype WHERE (ProductID IN (11, 21, 39, 45, 46, 51, 52, 57, 65, 70, 76, 80) OR RefTable = 2) AND Bettype = @BetType)
			BEGIN
				IF @WinLostDate >= DATEADD(DAY, DATEDIFF(DAY, 1, GETDATE()), 0)		-- yesterday and later
				BEGIN
					-- Yesterday and later running ticket
					INSERT INTO @Data (
						BetType, TransId, BetId, RefNo, MatchCode, Race, EventDate, VirtualRate, IsShowOTExRate,
						SDiscount, ADiscount, Discount, HomeId, AwayId, SettleTime, Hdp1, Hdp2, Odds, FinalOdds,
						FinalOdds2, OddsType, Status, SettlementStatus, ComStatus, Stake, Actual_Stake, TransDate,
						BetTeam, SPositionTaking, MPositionTaking, APositionTaking, SPositionTaking2, MPositionTaking2,
						APositionTaking2, LiveIndicator, Modds, CustId, LiveHomeScore, LiveAwayScore, FinalHomeScore,
						FinalAwayScore, LeagueId, SportType, Ip, MatchId, IsNeutral, WinLost, Commission, SComm,
						AComm, Comm, AWinLost, MWinLost, SWinLost, ShowTime, WinLostDate, BetCheck, TransDesc,
						OddsSpread, OriginalBetType, BetdaqId, ExtraInfo, JackpotInfo, WalletType, RefCode,
						CurrencyId, SiteId, LeagueGroupId, DeviceType
					)
					SELECT
						b.bettype,
						b.transid,
						ISNULL(b.BetID, 0) AS BetId,
						b.refno,
						'' AS matchcode,
						'' AS Race,
						'' AS eventdate,
						0 AS virtualrate,
						0 AS isShowOTExRate,
						AVG(blc.sdiscount) AS sdiscount,
						CASE
							WHEN b.mrecommend = -4 THEN 0
							ELSE AVG(blc.adiscount)
						END AS adiscount,
						CASE
							WHEN b.recommend IN (-3, -4) THEN 0
							ELSE AVG(blc.discount)
						END AS discount,
						0 AS homeid,
						0 AS awayid,
						'' AS settleTime,
						0 AS hdp1,
						0 AS hdp2,
						0 AS odds,
						0 AS finalodds,
						0 AS finalodds2,
						0 AS OddsType,
						'Running' AS Status,
						0 AS SettlementStatus,
						CASE WHEN b.comstatus = '1' THEN 1 ELSE 0 END AS comstatus,
						SUM(blc.stake) AS stake,
						SUM(blc.actual_stake) AS actual_stake,
						b.transdate,
						'' AS betteam,
						AVG(blc.spositiontaking) AS spositiontaking,
						AVG(blc.mpositiontaking) AS mpositiontaking,
						AVG(blc.apositiontaking) AS apositiontaking,
						0 AS SPositionTaking2,
						0 AS MPositionTaking2,
						0 AS APositionTaking2,
						0 AS liveindicator,
						0 AS modds,
						b.custid,
						0 AS livehomescore,
						0 AS liveawayscore,
						0,
						0,
						0 AS leagueid,
						CASE
							WHEN s.ProductID = 11 THEN 250
							WHEN s.ProductID = 21 THEN 211
							ELSE b.matchid
						END AS Sporttype,
						b.ip,
						0 AS MatchId,
						CONVERT(BIT, 0) AS IsNeutral,
						0 AS winlost,
						0 AS Commission,
						0 AS scomm,
						0 AS acomm,
						0 AS comm,
						0 AS awinlost,
						0 AS mwinlost,
						0 AS swinlost,
						'' AS showtime,
						b.winlostdate,
						'' AS BetCheck,
						'' AS TransDesc,
						0 AS OddsSpread,
						0 AS OriginalBetType,
						-1 AS BetdaqId,
						'' AS ExtraInfo,
						'' AS JackpotInfo,
						0 AS WalletType,
						0 AS RefCode,
						0 AS CurrencyId,
						'' AS SiteId,
						0 AS LeagueGroupID,
						b.DeviceType
					FROM dbo.bettransLC AS blc WITH (NOLOCK)
						INNER JOIN dbo.bettrans AS b WITH (NOLOCK) ON blc.RefNo = b.transid
						INNER JOIN @SportBettype AS s ON s.Bettype = b.bettype
					WHERE b.transid = @TransId
						AND (s.ProductID IN (11, 21, 39, 45, 46, 51, 52, 57, 65, 70, 76, 80) OR s.RefTable = 2)
						AND blc.statusID = 0
					GROUP BY
						b.transid,
						ISNULL(b.betid, 0),
						b.bettype,
						b.refno,
						b.transdate,
						b.winlostdate,
						b.custid,
						b.ip,
						b.comstatus,
						s.ProductID,
						b.matchid,
						b.DeviceType,
						b.mrecommend,
						b.recommend

					-- Yesterday and later settled ticket
					UNION ALL
					SELECT
						bcy.bettype,
						bcy.transid,
						ISNULL(bcy.betid, 0) AS BetId,
						bcy.refno,
						'' AS matchcode,
						'' AS Race,
						'' AS eventdate,
						0 AS virtualrate,
						0 AS isShowOTExRate,
						AVG(blc.sdiscount) AS sdiscount,
						CASE
							WHEN bcy.mrecommend = -4 THEN 0
							ELSE AVG(blc.adiscount)
						END AS adiscount,
						CASE
							WHEN bcy.recommend IN (-3, -4) THEN 0
							ELSE AVG(blc.discount)
						END AS discount,
						0 AS homeid,
						0 AS awayid,
						'' AS settleTime,
						0 AS hdp1,
						0 AS hdp2,
						CASE
							WHEN pj.ProductId IS NOT NULL
								THEN ISNULL(AVG(CASE WHEN blc.statusID IN (111, 112, 113) THEN blc.ContributionRate END), 0)
							ELSE 0
						END AS Odds,
						0 AS finalodds,
						0 AS finalodds2,
						0 AS OddsType,
						CASE 
							WHEN SUM(blc.winlost - blc.actual_stake) > 0 THEN 'Won'
							WHEN SUM(blc.winlost - blc.actual_stake) < 0 THEN 'Lose'
							ELSE 'Draw'
						END AS Status,
						0 AS SettlementStatus,
						CASE WHEN bcy.comstatus = '1' THEN 1 ELSE 0 END AS comstatus,
						SUM(blc.stake) AS stake,
						SUM(blc.actual_stake) AS actual_stake,
						bcy.transdate,
						'' AS betteam,
						AVG(blc.spositiontaking) AS spositiontaking,
						AVG(blc.mpositiontaking) AS mpositiontaking,
						AVG(blc.apositiontaking) AS apositiontaking,
						0 AS SPositionTaking2,
						0 AS MPositionTaking2,
						0 AS APositionTaking2,
						0 AS liveindicator,
						0 AS modds,
						bcy.custid,
						0 AS livehomescore,
						0 AS liveawayscore,
						0,
						0,
						0 AS leagueid,
						CASE
							WHEN s.ProductID = 11 THEN 250
							WHEN s.ProductID = 21 THEN 211
							ELSE bcy.matchid
						END AS Sporttype,
						bcy.ip,
						0 AS MatchId,
						CONVERT(BIT, 0) AS IsNeutral,
						SUM(blc.winlost - blc.actual_stake) AS winlost,
						SUM(blc.playercomm) AS Commission,
						SUM(blc.scomm - blc.acomm) AS scomm,
						SUM(blc.acomm - blc.comm) AS acomm,
						SUM(blc.comm - blc.playercomm) AS comm,
						SUM(blc.awinlost) AS awinlost,
						SUM(blc.mwinlost) AS mwinlost,
						SUM(blc.swinlost) AS swinlost,
						'' AS showtime,
						bcy.winlostdate,
						'' AS BetCheck,
						'' AS TransDesc,
						CASE
							WHEN pj.ProductId IS NOT NULL THEN ISNULL(SUM(blc.BetStake), 0)
							ELSE 0
						END AS OddsSpread,
						0 AS OriginalBetType,
						-1 AS BetdaqId,
						'' AS ExtraInfo,
						'' AS JackpotInfo,
						0 AS WalletType,
						0 AS RefCode,
						0 AS CurrencyId,
						'' AS SiteId,
						0 AS LeagueGroupID,
						bcy.DeviceType
					FROM dbo.bettransLC AS blc WITH (NOLOCK)
						INNER JOIN dbo.bettrans AS bcy WITH (NOLOCK) ON blc.RefNo = bcy.transid
						INNER JOIN @SportBettype AS s ON s.Bettype = bcy.bettype
						LEFT JOIN @ProductJackpot AS pj ON s.ProductId = pj.ProductId
					WHERE bcy.transid = @TransId
						AND (s.ProductID IN (11, 21, 39, 45, 46, 51, 52, 57, 65, 70, 76, 80) OR s.RefTable = 2)
						AND blc.statusID <> 0
					GROUP BY
						bcy.transid,
						pj.ProductId,
						ISNULL(bcy.betid, 0),
						bcy.bettype,
						bcy.refno,
						bcy.transdate,
						bcy.winlostdate,
						bcy.custid,
						bcy.ip,
						bcy.comstatus,
						s.ProductID,
						bcy.matchid,
						bcy.DeviceType,
						bcy.mrecommend,
						bcy.recommend,
						s.SubProduct
				END
				ELSE
				BEGIN
					-- Before yesterday settled ticket
					INSERT INTO @Data (
						BetType, TransId, BetId, RefNo, MatchCode, Race, EventDate, VirtualRate, IsShowOTExRate,
						SDiscount, ADiscount, Discount, HomeId, AwayId, SettleTime, Hdp1, Hdp2, Odds, FinalOdds,
						FinalOdds2, OddsType, Status, SettlementStatus, ComStatus, Stake, Actual_Stake, TransDate,
						BetTeam, SPositionTaking, MPositionTaking, APositionTaking, SPositionTaking2, MPositionTaking2,
						APositionTaking2, LiveIndicator, Modds, CustId, LiveHomeScore, LiveAwayScore, FinalHomeScore,
						FinalAwayScore, LeagueId, SportType, Ip, MatchId, IsNeutral, WinLost, Commission, SComm,
						AComm, Comm, AWinLost, MWinLost, SWinLost, ShowTime, WinLostDate, BetCheck, TransDesc,
						OddsSpread, OriginalBetType, BetdaqId, ExtraInfo, JackpotInfo, WalletType, RefCode,
						CurrencyId, SiteId, LeagueGroupId, DeviceType
					)
					SELECT
						bby.bettype,
						bby.transid,
						ISNULL(bby.BetID, 0) AS BetId,
						bby.refno,
						'' AS matchcode,
						'' AS Race,
						'' AS eventdate,
						0 AS virtualrate,
						0 AS isShowOTExRate,
						bby.sdiscount,
						CASE
							WHEN bby.mrecommend = -4 THEN 0
							ELSE bby.adiscount
						END,
						CASE
							WHEN bby.recommend IN (-3, -4) THEN 0
							ELSE bby.discount
						END,
						0 AS homeid,
						0 AS awayid,
						'' AS settleTime,
						0 AS hdp1,
						0 AS hdp2,
						CASE
							WHEN pj.ProductId IS NOT NULL THEN bby.odds
							ELSE 0
						END AS Odds,
						0 AS finalodds,
						0 AS finalodds2,
						0 AS OddsType,
						bby.status,
						0 AS SettlementStatus,
						CASE WHEN bby.comstatus = '1' THEN 1 ELSE 0 END AS comstatus,
						bby.stake,
						bby.actual_stake,
						bby.transdate,
						'' AS betteam,
						bby.spositiontaking,
						bby.mpositiontaking,
						bby.apositiontaking,
						0 AS SPositionTaking2,
						0 AS MPositionTaking2,
						0 AS APositionTaking2,
						0 AS liveindicator,
						0 AS modds,
						bby.custid,
						0 AS livehomescore,
						0 AS liveawayscore,
						0,
						0,
						0 AS leagueid,
						CASE
							WHEN s.ProductID = 11 THEN 250
							WHEN s.ProductID = 21 THEN 211
							ELSE bby.matchid
						END AS Sporttype,
						bby.ip,
						0 AS MatchId,
						CONVERT(BIT, 0) AS IsNeutral,
						(bby.winlost - bby.actual_stake) AS winlost,
						bby.playercomm AS Commission,
						(bby.scomm - bby.acomm) AS scomm,
						(bby.acomm - bby.comm) AS acomm,
						(bby.comm - bby.playercomm) AS comm,
						bby.awinlost,
						bby.mwinlost,
						bby.swinlost,
						'' AS showtime,
						bby.winlostdate,
						'' AS BetCheck,
						'' AS TransDesc,
						CASE
							WHEN pj.ProductId IS NOT NULL THEN ISNULL(bby.oddsspread, 0)
							ELSE 0
						END AS OddsSpread,
						0 AS OriginalBetType,
						-1 AS BetdaqId,
						'' AS ExtraInfo,
						'' AS JackpotInfo,
						0 AS WalletType,
						0 AS RefCode,
						bby.currency,
						'' AS SiteId,
						0 AS LeagueGroupID,
						bby.DeviceType
					FROM dbo.bettrans AS bby WITH (NOLOCK)
						INNER JOIN @SportBettype AS s ON s.Bettype = bby.bettype
						LEFT JOIN @ProductJackpot AS pj ON s.ProductId = pj.ProductId
					WHERE bby.transid = @TransId
						AND (s.ProductID IN (11, 21, 39, 45, 46, 51, 52, 57, 65, 70, 76, 80) OR s.RefTable = 2)
						
				END
			END

			-- Get related Bonus/Cash tickets
			IF EXISTS (SELECT 1 FROM @Data WHERE RefCode <> 0)
			BEGIN
				INSERT INTO @Data (
					BetType, TransId, BetId, RefNo, MatchCode, Race, EventDate, VirtualRate, IsShowOTExRate,
					SDiscount, ADiscount, Discount, HomeId, AwayId, SettleTime, Hdp1, Hdp2, Odds, FinalOdds,
					FinalOdds2, OddsType, Status, SettlementStatus, ComStatus, Stake, Actual_Stake, TransDate,
					BetTeam, SPositionTaking, MPositionTaking, APositionTaking, SPositionTaking2, MPositionTaking2,
					APositionTaking2, LiveIndicator, Modds, CustId, LiveHomeScore, LiveAwayScore, FinalHomeScore,
					FinalAwayScore, LeagueId, SportType, Ip, MatchId, IsNeutral, WinLost, Commission, SComm,
					AComm, Comm, AWinLost, MWinLost, SWinLost, ShowTime, WinLostDate, BetCheck, TransDesc,
					OddsSpread, OriginalBetType, BetdaqId, ExtraInfo, JackpotInfo, WalletType, RefCode,
					CurrencyId, SiteId, LeagueGroupId, DeviceType
				)
				SELECT
					bbc.bettype,
					bbc.transid,
					ISNULL(bbc.betid, 0) AS BetId,
					bbc.refno,
					m.matchcode,
					'' AS Race,
					m.GlobalShowTime AS EventDate,
					0 AS virtualrate,
					0 AS isShowOTExRate,
					bbc.sdiscount,
					CASE
						WHEN bbc.mrecommend = -4 THEN 0
						ELSE bbc.adiscount
					END,
					CASE
						WHEN bbc.recommend IN (-3, -4) THEN 0
						ELSE bbc.discount
					END,
					m.homeid,
					m.awayid,
					ISNULL(bbc.checktime,'') settleTime,
					bbc.hdp1,
					bbc.hdp2,
					bbc.odds,
					0 AS finalodds,
					0 AS finalodds2,
					bbc.oddstype,
					CASE
						WHEN bbc.status = 'running' AND ISNULL(bbc.SecAcceptFlag, 0) = 1 AND ISNULL(bbc.checktime, CURRENT_TIMESTAMP) > CURRENT_TIMESTAMP THEN 'waiting'
						ELSE bbc.status
					END AS status,
					ISNULL(m.SettlementStatus, 0) AS SettlementStatus,
					CASE WHEN bbc.comstatus = '1' THEN 1 ELSE 0 END AS comstatus,
					bbc.stake,
					bbc.actual_stake,
					bbc.transdate,
					bbc.betteam,
					bbc.spositiontaking,
					bbc.mpositiontaking,
					bbc.apositiontaking,
					0 AS SPositionTaking2,
					0 AS MPositionTaking2,
					0 AS APositionTaking2,
					bbc.liveindicator,
					bbc.modds,
					bbc.custid,
					bbc.livehomescore,
					bbc.liveawayscore,
					m.finalhomescore,
					m.finalawayscore,
					m.leagueid,
					m.sporttype,
					bbc.ip,
					bbc.matchid,
					ISNULL(m.isNeutral, CONVERT(BIT,0)) AS IsNeutral,
					(bbc.winlost - bbc.actual_stake) AS winlost,
					bbc.playercomm AS Commission,
					(bbc.scomm - bbc.acomm) AS scomm,
					(bbc.acomm - bbc.comm) AS acomm,
					(bbc.comm - bbc.playercomm) AS comm,
					bbc.awinlost,
					bbc.mwinlost,
					bbc.swinlost,
					m.showtime,
					bbc.winlostdate,
					bbc.BetCheck,
					ISNULL(bbc.transdesc, '') AS TransDesc,
					ISNULL(bbc.oddsspread, 0) AS OddsSpread,
					0 AS OriginalBetType,
					-1 AS BetdaqId,
					ISNULL(bbc.ExtraInfo, '') AS ExtraInfo,
					'' AS JackpotInfo,
					ISNULL(bbc.WalletType, 0) AS WalletType,
					ISNULL(bbc.RefCode, 0) AS RefCode,
					bbc.currency,
					'' AS SiteId,
					0 AS LeagueGroupID,
					bbc.DeviceType
				FROM
					dbo.bettrans AS bbc WITH (NOLOCK)
					INNER JOIN @Data AS b1
						ON bbc.custid = b1.CustId
						AND bbc.winlostdate = b1.WinLostDate
						AND bbc.RefCode = b1.RefCode
						AND bbc.transid <> b1.TransId
					INNER JOIN dbo.match AS m WITH (NOLOCK) ON bbc.matchid = m.matchid
			END
		END

		-- Bettrans14
		ELSE IF @WinLostDate BETWEEN @BalanceUpDay AND @MoveBetsDay
		BEGIN
			-- Sportbooks, Number Game, Virtual Sports, Betradar Virtual Sports, Cash Out, Virtual Sports 3 (new), Virtual Sports 4
			IF EXISTS (SELECT TOP(1) 1 FROM @SportBettype WHERE EventType = 1 AND BetType = @BetType )
			BEGIN
				INSERT INTO @Data (
					BetType, TransId, BetId, RefNo, MatchCode, Race, EventDate, VirtualRate, IsShowOTExRate,
					SDiscount, ADiscount, Discount, HomeId, AwayId, SettleTime, Hdp1, Hdp2, Odds, FinalOdds,
					FinalOdds2, OddsType, Status, SettlementStatus, ComStatus, Stake, Actual_Stake, TransDate,
					BetTeam, SPositionTaking, MPositionTaking, APositionTaking, SPositionTaking2, MPositionTaking2,
					APositionTaking2, LiveIndicator, Modds, CustId, LiveHomeScore, LiveAwayScore, FinalHomeScore,
					FinalAwayScore, LeagueId, SportType, Ip, MatchId, IsNeutral, WinLost, Commission, SComm,
					AComm, Comm, AWinLost, MWinLost, SWinLost, ShowTime, WinLostDate, BetCheck, TransDesc,
					OddsSpread, OriginalBetType, BetdaqId, ExtraInfo, JackpotInfo, WalletType, RefCode,
					CurrencyId, SiteId, LeagueGroupId, DeviceType
				)
				SELECT
					b14.bettype,
					b14.transid,
					ISNULL(b14.betid, 0) AS BetId,
					b14.refno,
					m14.matchcode,
					'' AS Race,
					CASE
						WHEN s.ProductID IN (1, 25) THEN m14.GlobalShowTime
						ELSE m14.eventdate
					END AS EventDate,
					0 AS virtualrate,
					0 AS isShowOTExRate,
					b14.sdiscount,
					CASE
						WHEN b14.mrecommend = -4 THEN 0
						ELSE b14.adiscount
					END,
					CASE
						WHEN b14.recommend IN (-3, -4) THEN 0
						ELSE b14.discount
					END,
					m14.homeid,
					m14.awayid,
					ISNULL(b14.checktime,'') settleTime,
					b14.hdp1,
					b14.hdp2,
					b14.odds,
					0 AS finalodds,
					0 AS finalodds2,
					b14.OddsType,
					b14.status,
					0 AS SettlementStatus,
					CASE WHEN b14.comstatus = '1' THEN 1 ELSE 0 END AS comstatus,
					b14.stake,
					b14.actual_stake,
					b14.transdate,
					b14.betteam,
					b14.spositiontaking,
					b14.mpositiontaking,
					b14.apositiontaking,
					0 AS SPositionTaking2,
					0 AS MPositionTaking2,
					0 AS APositionTaking2,
					b14.liveindicator,
					b14.modds,
					b14.custid,
					b14.livehomescore,
					b14.liveawayscore,
					m14.finalhomescore,
					m14.finalawayscore,
					m14.leagueid,
					m14.sporttype,
					b14.ip,
					b14.matchid,
					ISNULL(m14.IsNeutral, CONVERT(BIT,0)) AS IsNeutral,
					(b14.winlost - b14.actual_stake) AS winlost,
					b14.playercomm AS Commission,
					(b14.scomm - b14.acomm) AS scomm,
					(b14.acomm - b14.comm) AS acomm,
					(b14.comm - b14.playercomm) AS comm,
					b14.awinlost,
					b14.mwinlost,
					b14.swinlost,
					CASE
						WHEN s.ProductID IN (5, 27, 77) THEN CONVERT(NVARCHAR(50), m14.kickofftime)
						ELSE m14.showtime
					END AS ShowTime,
					b14.winlostdate,
					b14.BetCheck,
					ISNULL(b14.transdesc, '') AS TransDesc,
					ISNULL(b14.oddsspread, 0) AS OddsSpread,
					0 AS OriginalBetType,
					CASE
						WHEN s.ProductID = 1 THEN ISNULL(b14.betdaqid, -1)
						ELSE -1
					END AS BetdaqId,
					ISNULL(b14.ExtraInfo, '') AS ExtraInfo,
					'' AS JackpotInfo,
					CASE
						WHEN s.ProductID = 1 THEN ISNULL(b14.WalletType, 0)
						ELSE 0
					END AS WalletType,
					CASE
						WHEN s.ProductID = 1 THEN ISNULL(b14.RefCode, 0)
						ELSE 0
					END AS RefCode,
					b14.currency,
					'' AS SiteId,
					l14.LeagueGroupID,
					b14.DeviceType
				FROM dbo.bettrans14 AS b14 WITH (NOLOCK)
					INNER JOIN @SportBettype AS s ON s.Bettype = b14.bettype
					INNER JOIN dbo.match14 AS m14 WITH (NOLOCK) ON b14.matchid = m14.matchid
					LEFT JOIN dbo.league AS l14 WITH (NOLOCK) ON l14.leagueid = m14.leagueid
				WHERE s.EventType = 1 AND b14.transid = @TransId
			END

			-- Get more info for BetTrade tickets
			IF EXISTS (SELECT TOP(1) 1 FROM @Data WHERE SportType = 1 AND BetType = 901)
			BEGIN
				UPDATE b14
				SET b14.Odds = ob14.odds,
					b14.Stake = ob14.stake,
					b14.LiveHomeScore = ob14.livehomescore,
					b14.LiveAwayScore = ob14.liveawayscore,
					b14.BetId = ob14.bettype
				FROM @Data AS b14
					INNER JOIN dbo.bettrans14 AS ob14 WITH (NOLOCK) ON b14.RefNo = ob14.transid
				WHERE b14.SportType = 1 AND b14.BetType = 901
			END

			IF EXISTS (SELECT TOP(1) 1 FROM @Data WHERE SportType = 1 AND BetType = 902)
			BEGIN
				UPDATE b14
				SET b14.Odds = ob14.odds,
					b14.Stake = ob14.stake,
					b14.LiveHomeScore = ob14.livehomescore,
					b14.LiveAwayScore = ob14.liveawayscore,
					b14.Comm = ISNULL(cb14.awinlost, 0),
					b14.BetId = ob14.bettype
				FROM @Data AS b14
					INNER JOIN dbo.bettrans14 AS ob14 WITH (NOLOCK) ON b14.RefNo = ob14.transid
					LEFT JOIN dbo.bettrans14 AS cb14 WITH (NOLOCK)
						ON b14.RefNo = cb14.refno
						AND cb14.bettype = 903
						AND cb14.custid = @CustId
						AND cb14.winlostdate = @WinLostDate
				WHERE b14.SportType = 1 AND b14.BetType = 902
			END

			-- Get more info for CashOut tickets
			IF EXISTS (SELECT TOP(1) 1 FROM @Data WHERE BetType = 911)
			BEGIN
				UPDATE b14
				SET b14.Odds = ob14.odds,
					b14.LiveIndicator = ob14.liveindicator,
					b14.LiveHomeScore = ob14.livehomescore,
					b14.LiveAwayScore = ob14.liveawayscore,
					b14.OriginalBetType = ob14.bettype,
					b14.BetdaqId = ob14.transid
				FROM @Data AS b14
					INNER JOIN dbo.bettrans14 AS ob14 WITH (NOLOCK) ON b14.RefNo = ob14.transid
				WHERE b14.BetType = 911
			END

			IF EXISTS (SELECT TOP(1) 1 FROM @Data WHERE BetType = 912)
			BEGIN
				UPDATE b14
				SET b14.Odds = ob14.odds,
					b14.LiveIndicator = ob14.liveindicator,
					b14.LiveHomeScore = ob14.livehomescore,
					b14.LiveAwayScore = ob14.liveawayscore,
					b14.OriginalBetType = ob14.bettype,
					b14.BetdaqId = ob14.transid,
					b14.Stake = cob14.stake,
					b14.Comm = ISNULL(cb14.AWinLost, 0)
				FROM @Data AS b14
					INNER JOIN dbo.bettrans14 AS cob14 WITH (NOLOCK) ON b14.RefNo = cob14.transid
					INNER JOIN dbo.bettrans14 AS ob14 WITH (NOLOCK) ON cob14.RefNo = ob14.transid
					LEFT JOIN dbo.bettrans14 AS cb14 WITH (NOLOCK)
						ON b14.RefNo = cb14.refno
						AND cb14.BetType = 913
						AND cb14.custid = @CustId
						AND cb14.winlostdate = @WinLostDate
				WHERE b14.BetType = 912
			END

			-- Bitcoin, Virtual Sports 5, VS6
			IF EXISTS (SELECT TOP(1) 1 FROM @SportBettype WHERE EventType = 5 AND BetType = @BetType )
			BEGIN
				INSERT INTO @Data (
					BetType, TransId, BetId, RefNo, MatchCode, Race, EventDate, VirtualRate, IsShowOTExRate,
					SDiscount, ADiscount, Discount, HomeId, AwayId, SettleTime, Hdp1, Hdp2, Odds, FinalOdds,
					FinalOdds2, OddsType, Status, SettlementStatus, ComStatus, Stake, Actual_Stake, TransDate,
					BetTeam, SPositionTaking, MPositionTaking, APositionTaking, SPositionTaking2, MPositionTaking2,
					APositionTaking2, LiveIndicator, Modds, CustId, LiveHomeScore, LiveAwayScore, FinalHomeScore,
					FinalAwayScore, LeagueId, SportType, Ip, MatchId, IsNeutral, WinLost, Commission, SComm,
					AComm, Comm, AWinLost, MWinLost, SWinLost, ShowTime, WinLostDate, BetCheck, TransDesc,
					OddsSpread, OriginalBetType, BetdaqId, ExtraInfo, JackpotInfo, WalletType, RefCode,
					CurrencyId, SiteId, LeagueGroupId, DeviceType
				)
				SELECT
					b14.bettype,
					b14.transid,
					ISNULL(b14.betid, 0) AS BetId,
					b14.refno,
					m14.matchcode,
					'' AS Race,
					m14.EndTime AS EventDate,
					0 AS virtualrate,
					0 AS isShowOTExRate,
					b14.sdiscount,
					CASE
						WHEN b14.mrecommend = -4 THEN 0
						ELSE b14.adiscount
					END,
					CASE
						WHEN b14.recommend IN (-3, -4) THEN 0
						ELSE b14.discount
					END,
					m14.homeid,
					m14.awayid,
					ISNULL(b14.checktime,'') settleTime,
					b14.hdp1,
					b14.hdp2,
					b14.odds,
					0 AS finalodds,
					0 AS finalodds2,
					b14.OddsType,
					b14.status,
					0 AS SettlementStatus,
					0 AS comstatus,
					b14.stake,
					b14.actual_stake,
					b14.transdate,
					b14.betteam,
					b14.spositiontaking,
					b14.mpositiontaking,
					b14.apositiontaking,
					0 AS SPositionTaking2,
					0 AS MPositionTaking2,
					0 AS APositionTaking2,
					b14.liveindicator,
					b14.modds,
					b14.custid,
					b14.livehomescore,
					b14.liveawayscore,
					m14.finalhomescore,
					m14.finalawayscore,
					m14.league3rdid,
					m14.sporttype,
					b14.ip,
					b14.matchid,
					CONVERT(BIT,0) AS IsNeutral,
					(b14.winlost - b14.actual_stake) AS winlost,
					b14.playercomm AS Commission,
					(b14.scomm - b14.acomm) AS scomm,
					(b14.acomm - b14.comm) AS acomm,
					(b14.comm - b14.playercomm) AS comm,
					b14.awinlost,
					b14.mwinlost,
					b14.swinlost,
					CONVERT(NVARCHAR(50), m14.StartTime) AS ShowTime,
					b14.winlostdate,
					b14.BetCheck,
					ISNULL(b14.transdesc, '') AS TransDesc,
					ISNULL(b14.oddsspread, 0) AS OddsSpread,
					0 AS OriginalBetType,
						-1 AS BetdaqId,
					ISNULL(b14.ExtraInfo, '') AS ExtraInfo,
					'' AS JackpotInfo,
					0 AS WalletType,
					0 AS RefCode,
					b14.currency,
					'' AS SiteId,
					0 AS LeagueGroupID,
					b14.DeviceType
				FROM dbo.bettrans14 AS b14 WITH (NOLOCK)
					INNER JOIN @SportBettype AS s ON s.Bettype = b14.bettype
					INNER JOIN dbo.match3rd14 AS m14 WITH (NOLOCK) ON b14.matchid = m14.match3rdid
				WHERE s.EventType = 5 AND b14.transid = @TransId
			END

			-- Mix Parlay, Combination Mix Parlay, Mix Parlay (VS4), Mix Parlay (VS5)
			IF @BetType IN (9, 29, 2798, 2799, 10449, 11099)
			BEGIN
				INSERT INTO @Data (
					BetType, TransId, BetId, RefNo, MatchCode, Race, EventDate, VirtualRate, IsShowOTExRate,
					SDiscount, ADiscount, Discount, HomeId, AwayId, SettleTime, Hdp1, Hdp2, Odds, FinalOdds,
					FinalOdds2, OddsType, Status, SettlementStatus, ComStatus, Stake, Actual_Stake, TransDate,
					BetTeam, SPositionTaking, MPositionTaking, APositionTaking, SPositionTaking2, MPositionTaking2,
					APositionTaking2, LiveIndicator, Modds, CustId, LiveHomeScore, LiveAwayScore, FinalHomeScore,
					FinalAwayScore, LeagueId, SportType, Ip, MatchId, IsNeutral, WinLost, Commission, SComm,
					AComm, Comm, AWinLost, MWinLost, SWinLost, ShowTime, WinLostDate, BetCheck, TransDesc,
					OddsSpread, OriginalBetType, BetdaqId, ExtraInfo, JackpotInfo, WalletType, RefCode,
					CurrencyId, SiteId, LeagueGroupId, DeviceType
				)
				SELECT
					b14.bettype,
					b14.transid,
					ISNULL(b14.betid, 0) AS BetId,
					b14.refno,
					'' AS MatchCode,
					'' AS Race,
					'' AS EventDate,
					0 AS VirtualRate,
					0 AS IsShowOTExRate,
					b14.sdiscount,
					CASE
						WHEN b14.mrecommend = -4 THEN 0
						ELSE b14.adiscount
					END,
					CASE
						WHEN b14.recommend IN (-3, -4) THEN 0
						ELSE b14.discount
					END,
					0 AS HomeId,
					0 AS AwayId,
					'' AS SettleTime,
					b14.hdp1,
					b14.hdp2,
					b14.odds,
					0 AS FinalOdds,
					0 AS FinalOdds2,
					0 AS OddsType,
					b14.status,
					0 AS SettlementStatus,
					CASE WHEN b14.comstatus = '1' THEN 1 ELSE 0 END AS comstatus,
					b14.stake,
					b14.actual_stake,
					b14.transdate,
					b14.betteam,
					b14.spositiontaking,
					b14.mpositiontaking,
					b14.apositiontaking,
					0 AS SPositionTaking2,
					0 AS MPositionTaking2,
					0 AS APositionTaking2,
					0 AS LiveIndicator,
					b14.modds,
					b14.custid,
					b14.livehomescore,
					b14.liveawayscore,
					0 AS FinalHomeScore,
					0 AS FinalAwayScore,
					0 AS LeagueId,
					0 AS SportType,
					b14.ip,
					0 AS MatchId,
					CONVERT(BIT, 0) AS IsNeutral,
					(b14.winlost - b14.actual_stake) AS WinLost,
					b14.playercomm AS Commission,
					(b14.scomm - b14.acomm) AS SComm,
					(b14.acomm - b14.comm) AS AComm,
					(b14.comm - b14.playercomm) AS Comm,
					b14.awinlost,
					b14.mwinlost,
					b14.swinlost,
					'' AS ShowTime,
					b14.winlostdate,
					b14.betcheck,
					IIF(b14.bettype = 29 AND b14.oddsspread = 3, ISNULL(b14.transdesc, ''), '') AS TransDesc,
					ISNULL(b14.oddsspread, 0) AS OddsSpread,
					0 AS OriginalBetType,
					-1 AS BetdaqId,
					ISNULL(b14.ExtraInfo, '') AS ExtraInfo,
					'' AS JackpotInfo,
					0 AS WalletType,
					0 AS RefCode,
					b14.currency,
					'' AS SiteId,
					0 AS LeagueGroupID,
					b14.DeviceType
				FROM dbo.bettrans14 AS b14 WITH (NOLOCK)
				WHERE b14.transid = @TransId AND b14.bettype IN (9, 29, 2798, 2799, 10449, 11099)
			END

			-- Outright
			IF @BetType = 10
			BEGIN
				INSERT INTO @Data (
					BetType, TransId, BetId, RefNo, MatchCode, Race, EventDate, VirtualRate, IsShowOTExRate,
					SDiscount, ADiscount, Discount, HomeId, AwayId, SettleTime, Hdp1, Hdp2, Odds, FinalOdds,
					FinalOdds2, OddsType, Status, SettlementStatus, ComStatus, Stake, Actual_Stake, TransDate,
					BetTeam, SPositionTaking, MPositionTaking, APositionTaking, SPositionTaking2, MPositionTaking2,
					APositionTaking2, LiveIndicator, Modds, CustId, LiveHomeScore, LiveAwayScore, FinalHomeScore,
					FinalAwayScore, LeagueId, SportType, Ip, MatchId, IsNeutral, WinLost, Commission, SComm,
					AComm, Comm, AWinLost, MWinLost, SWinLost, ShowTime, WinLostDate, BetCheck, TransDesc,
					OddsSpread, OriginalBetType, BetdaqId, ExtraInfo, JackpotInfo, WalletType, RefCode,
					CurrencyId, SiteId, LeagueGroupId, DeviceType
				)
				SELECT 
					b14.bettype,
					b14.transid,
					ISNULL(b14.BetID,0) AS BetId,
					b14.refno,
					odds14.matchcode, 
					odds14.groupmatch AS race,
					odds14.eventdate,
					0 AS virtualrate,
					0 AS isShowOTExRate,
					b14.sdiscount,
					CASE
						WHEN b14.mrecommend = -4 THEN 0
						ELSE b14.adiscount
					END,
					CASE
						WHEN b14.recommend IN (-3, -4) THEN 0
						ELSE b14.discount
					END,
					0 AS homeid,
					odds14.teamid AS awayid,
					'' settleTime, 
					b14.hdp1,
					b14.hdp2,
					b14.odds,
					0 AS finalodds,
					0 AS finalodds2,
					b14.oddstype AS OddsType,
					b14.status,
					0 AS SettlementStatus,
					CASE WHEN b14.comstatus = '1' THEN 1 ELSE 0 END AS comstatus,
					b14.stake,
					b14.actual_stake,
					b14.transdate,
					b14.betteam,
					b14.spositiontaking,
					b14.mpositiontaking,
					b14.apositiontaking,
					0 AS SPositionTaking2,
					0 AS MPositionTaking2,
					0 AS APositionTaking2,
					b14.liveindicator,
					b14.modds,
					b14.custid,
					b14.livehomescore,
					b14.liveawayscore,
					0,
					0,
					odds14.leagueid,
					l14.sporttype,
					b14.ip,
					b14.matchid,
					CONVERT(BIT,0) AS IsNeutral,
					(b14.winlost-b14.actual_stake)  winlost,
					b14.playercomm AS Commission,
					(b14.scomm - b14.acomm) AS scomm,
					(b14.acomm - b14.comm) AS acomm,
					(b14.comm - b14.playercomm) AS comm,
					b14.awinlost,
					b14.mwinlost,
					b14.swinlost,
					'' AS showtime,
					b14.winlostdate,
					b14.BetCheck,
					'' AS TransDesc,
					0 AS OddsSpread,
					0 AS OriginalBetType,
					-1 AS BetdaqId,
					'' AS ExtraInfo,
					'' AS JackpotInfo,
					0 AS WalletType,
					0 AS RefCode,
					b14.currency,
					'' AS SiteId,
					0 AS LeagueGroupID,
					b14.DeviceType
				FROM dbo.bettrans14 AS b14 WITH (NOLOCK)
					INNER JOIN dbo.outright14 AS odds14 WITH (NOLOCK) ON b14.matchid = odds14.orid
					INNER JOIN dbo.league l14 WITH (NOLOCK) ON odds14.leagueid = l14.leagueid
				WHERE b14.bettype = 10
					AND b14.transid = @TransId
			END

			-- Virtual Horse Racing, VS2 Racing, VS7
			IF EXISTS(SELECT TOP(1) 1 FROM @SportBettype WHERE ProductID IN (5, 27, 106) AND EventType = 3 AND BetType = @BetType)
			BEGIN
				INSERT INTO @Data (
					BetType, TransId, BetId, RefNo, MatchCode, Race, EventDate, VirtualRate, IsShowOTExRate,
					SDiscount, ADiscount, Discount, HomeId, AwayId, SettleTime, Hdp1, Hdp2, Odds, FinalOdds,
					FinalOdds2, OddsType, Status, SettlementStatus, ComStatus, Stake, Actual_Stake, TransDate,
					BetTeam, SPositionTaking, MPositionTaking, APositionTaking, SPositionTaking2, MPositionTaking2,
					APositionTaking2, LiveIndicator, Modds, CustId, LiveHomeScore, LiveAwayScore, FinalHomeScore,
					FinalAwayScore, LeagueId, SportType, Ip, MatchId, IsNeutral, WinLost, Commission, SComm,
					AComm, Comm, AWinLost, MWinLost, SWinLost, ShowTime, WinLostDate, BetCheck, TransDesc,
					OddsSpread, OriginalBetType, BetdaqId, ExtraInfo, JackpotInfo, WalletType, RefCode,
					CurrencyId, SiteId, LeagueGroupId, DeviceType
				)
				SELECT 
					b14.bettype,
					b14.transid,
					'' AS BetId,
					b14.refno,
					'' AS matchcode, --Horse Number
					b14.oddsid AS Race, --Outright ID
					'' eventdate,
					0 AS virtualrate,
					0 AS isShowOTExRate,
					b14.sdiscount,
					CASE
						WHEN b14.mrecommend = -4 THEN 0
						ELSE b14.adiscount
					END,
					CASE
						WHEN b14.recommend IN (-3, -4) THEN 0
						ELSE b14.discount
					END,
					0 AS homeID,
					0 AS awayID,
					'' settleTime,
					b14.hdp1,
					b14.hdp2,
					b14.odds,
					0 AS finalodds,
					0 AS finalodds2,
					b14.OddsType,
					b14.status,
					0 AS SettlementStatus,
					CASE WHEN b14.comstatus = '1' THEN 1 ELSE 0 END AS comstatus,
					b14.stake,
					b14.actual_stake,
					b14.transdate,
					b14.betteam AS betteam, 
					CASE WHEN b14.bettype = 1233 THEN bm14.spositiontaking ELSE b14.spositiontaking END,
					CASE WHEN b14.bettype = 1233 THEN bm14.mpositiontaking ELSE b14.mpositiontaking END,
					CASE WHEN b14.bettype = 1233 THEN bm14.apositiontaking ELSE b14.apositiontaking END,
					CASE WHEN b14.bettype = 1233 THEN bm14.spositiontaking2 ELSE 0 END,
					CASE WHEN b14.bettype = 1233 THEN bm14.mpositiontaking2 ELSE 0 END,
					CASE WHEN b14.bettype = 1233 THEN bm14.apositiontaking2 ELSE 0 END,
					0 liveindicator,
					b14.modds,
					b14.custid,
					b14.livehomescore, 
					b14.liveawayscore, 
					0 finalhomescore, 
					0 finalawayscore, 
					r14.leagueid,
					r14.sporttype,
					b14.ip,
					b14.matchid,
					CONVERT(BIT, 0) AS IsNeutral,
					(b14.winlost - b14.actual_stake) AS WinLost,
					b14.playercomm AS Commission,
					(b14.scomm - b14.acomm) AS scomm,
					(b14.acomm - b14.comm) AS acomm,
					(b14.comm - b14.playercomm) AS comm,
					b14.awinlost,
					b14.mwinlost,
					b14.swinlost,
					'' AS showtime, -- Race Name
					b14.winlostdate,
					b14.BetCheck,
					b14.TransDesc AS TransDesc,
						0 AS OddsSpread,
					0 AS OriginalBetType,
					-1 AS BetdaqId,
					b14.ExtraInfo,
					'' AS JackpotInfo,
					0 AS WalletType,
					0 AS RefCode,
					b14.currency,
					'' AS SiteId,
					0 AS LeagueGroupID,
					b14.DeviceType
				FROM 
					dbo.bettrans14 AS b14 WITH (NOLOCK)
					INNER JOIN dbo.VSRaceInfo14 AS r14 WITH (NOLOCK) ON r14.EventID = b14.matchid
					INNER JOIN @SportBettype AS s ON s.BetType = b14.BetType 
					LEFT JOIN (
						SELECT 
							t14.refno, 
							t14.apositiontaking,
							t14.mpositiontaking,
							t14.spositiontaking,
							f14.apositiontaking apositiontaking2,
							f14.mpositiontaking mpositiontaking2,
							f14.spositiontaking spositiontaking2
						FROM dbo.bettransm14 AS t14 WITH (NOLOCK)
							INNER JOIN dbo.bettransm14 AS f14 WITH (NOLOCK) ON t14.refno = f14.refno
						WHERE t14.bettype = 1231 AND f14.bettype = 1232 
						) bm14 ON b14.refno = bm14.refno
				WHERE b14.transid = @TransId
					AND s.EventType = 3
			END

			-- RNG Casino, Keno, AG Casino, AllBet, Macau Games, NG2, Lottery, Pragmatic Casino
			-- Card Club, NPH Promotion, Spadegaming, Virtual Games, SA Gaming, Indo 4D, Sexy Gaming, Saba.club, Table Games, BBIN
			-- IBCBet Live Casino, RNG War, ION, PG Soft, Joker, WM, Leap Gaming Virtual Sports, Big Gaming, Happy 5 Linked Games (Number Game)
			-- MaxGame, Habanero, CG, Sports Lottery, PP Live Casino, VGaming, AdvantPlay, AdvantPlay Mini, FGG, SEAL Entertainment, MG RNG Casino, Player Tips, Jili, WE, Live22, UU Slots, Saba xD
			-- Saba Coins
			IF EXISTS (SELECT TOP(1) 1 FROM @SportBettype
						WHERE Bettype = @BetType
							AND (ProductID IN (6, 8, 11, 21, 22, 23, 28, 32, 34, 36, 37, 38, 39, 40, 42, 43, 45, 46, 47, 49, 50, 51, 52, 55, 56, 57, 60, 61, 62, 63, 65, 66, 67, 68, 70, 72, 73, 74, 75, 76, 78, 79, 80, 86, 81))
									OR (ProductID = 3 AND EventType = 0)
									OR RefTable IN (1, 2))
			BEGIN
				INSERT INTO @Data (
					BetType, TransId, BetId, RefNo, MatchCode, Race, EventDate, VirtualRate, IsShowOTExRate,
					SDiscount, ADiscount, Discount, HomeId, AwayId, SettleTime, Hdp1, Hdp2, Odds, FinalOdds,
					FinalOdds2, OddsType, Status, SettlementStatus, ComStatus, Stake, Actual_Stake, TransDate,
					BetTeam, SPositionTaking, MPositionTaking, APositionTaking, SPositionTaking2, MPositionTaking2,
					APositionTaking2, LiveIndicator, Modds, CustId, LiveHomeScore, LiveAwayScore, FinalHomeScore,
					FinalAwayScore, LeagueId, SportType, Ip, MatchId, IsNeutral, WinLost, Commission, SComm,
					AComm, Comm, AWinLost, MWinLost, SWinLost, ShowTime, WinLostDate, BetCheck, TransDesc,
					OddsSpread, OriginalBetType, BetdaqId, ExtraInfo, JackpotInfo, WalletType, RefCode,
					CurrencyId, SiteId, LeagueGroupId, DeviceType
				)
				SELECT
					b14.bettype,
					b14.transid,
					ISNULL(b14.betid, 0) AS BetId,
					b14.refno,
					'' AS matchcode,
					'' AS Race,
					'' AS eventdate,
					0 AS virtualrate,
					0 AS isShowOTExRate,
					b14.sdiscount,
					CASE
						WHEN b14.mrecommend = -4 THEN 0
						ELSE b14.adiscount
					END,
					CASE
						WHEN b14.recommend IN (-3, -4) THEN 0
						ELSE b14.discount
					END,
					0 AS homeid,
					0 AS awayid,
					'' AS settleTime,
					CASE
						WHEN s.ProductId = 23 THEN b14.hdp1
						ELSE 0
					END AS hdp1,
					CASE
						WHEN s.ProductId = 23 THEN b14.hdp2
						ELSE 0
					END AS hdp2,
					CASE
						WHEN s.ProductID IN (3, 6, 8, 23, 28, 32, 36, 38, 40, 42, 43, 49, 63, 66) THEN b14.odds
						ELSE 0
					END AS odds,
					0 AS finalodds,
					0 AS finalodds2,
					0 AS OddsType,
					CASE
						WHEN s.ProductID = 40 AND b14.status = 'Won' AND b14.modds = 0.25 THEN 'Half Won'
						WHEN s.ProductID = 40 AND b14.status = 'Lose' AND b14.modds = -0.25 THEN 'Half Lose'
						ELSE b14.status
					END AS status,
					0 AS SettlementStatus,
					'' AS comstatus,
					b14.stake,
					b14.actual_stake,
					b14.transdate,
					'' AS betteam,
					b14.spositiontaking,
					b14.mpositiontaking,
					b14.apositiontaking,
					0 AS SPositionTaking2,
					0 AS MPositionTaking2,
					0 AS APositionTaking2,
					0 AS liveindicator,
					0 AS modds,
					b14.custid,
					CASE
						WHEN s.ProductId = 23 THEN b14.livehomescore
						ELSE 0
					END AS livehomescore,
					0 AS LiveAwayScore,
					0 AS finalhomescore,
					0 AS finalawayscore,
					0 AS leagueid,
					CASE
						WHEN s.ProductID IN (3, 6, 34, 36, 37, 38, 39, 40, 42, 43, 45, 46, 47, 49, 50, 51, 52, 55, 56, 57, 60, 61, 62, 63, 65, 66, 67, 68, 70, 72, 73, 74, 75, 76, 78, 79, 80, 86, 81) THEN b14.matchid
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
						WHEN s.RefTable IN (1, 2) THEN b14.matchid
						ELSE 0
					END AS SportType,
					b14.ip,
					CASE
						WHEN s.ProductID = 23 THEN b14.betdaqid
						WHEN s.ProductID = 74 THEN ISNULL(CAST(('<xml>' + b14.ExtraInfo + '</xml>') AS XML).value('data(/xml/p74/@m)[1]','INT'), 0)
						ELSE 0
					END AS MatchId,
					CONVERT(BIT, 0) AS IsNeutral,
					(b14.winlost - b14.actual_stake) AS winlost,
					b14.playercomm AS Commission,
					(b14.scomm - b14.acomm) AS scomm,
					(b14.acomm - b14.comm) AS acomm,
					(b14.comm - b14.playercomm) AS comm,
					b14.awinlost,
					b14.mwinlost,
					b14.swinlost,
					'' AS showtime,
					b14.winlostdate,
					CASE
						WHEN s.ProductID IN (3, 38, 63) THEN b14.betcheck
						WHEN s.ProductId = 8 THEN ISNULL(b14.comstatus, '')
						ELSE ''
					END AS BetCheck,
					CASE
						WHEN s.ProductID IN (3, 6, 8, 22, 23, 28, 32, 34, 36, 38, 40, 43, 49, 55, 56, 61, 62, 63, 67, 68, 72) THEN b14.transdesc
						ELSE ''
					END AS TransDesc,
					CASE
						WHEN pj.ProductId IS NOT NULL THEN ISNULL(b14.oddsspread, 0)
						ELSE 0
					END AS OddsSpread,
					0 AS OriginalBetType,
					-1 AS BetdaqId,
					ISNULL(b14.ExtraInfo, '') AS ExtraInfo,
					'' AS JackpotInfo,
					0 AS WalletType,
					0 AS RefCode,
					b14.currency,
					CASE 
						WHEN s.ProductId = 3 AND s.EventType = 0 THEN CONVERT(VARCHAR(20), b14.betdaqid)
						WHEN s.ProductId IN (38, 63) THEN CONVERT(VARCHAR(20), b14.betdaqid)
						ELSE '' 
					END AS SiteId,
					0 AS LeagueGroupID,
					b14.DeviceType
				FROM dbo.bettrans14 AS b14 WITH (NOLOCK)
					INNER JOIN @SportBettype AS s ON s.Bettype = b14.bettype
					LEFT JOIN @ProductJackpot AS pj ON s.ProductId = pj.ProductId
				WHERE b14.transid = @TransID
					AND (s.ProductID IN (6, 8, 11, 21, 22, 23, 28, 32, 34, 36, 37, 38, 39, 40, 42, 43, 45, 46, 47, 49, 50, 51, 52, 55, 56, 57, 60, 61, 62, 63, 65, 66, 67, 68, 70, 72, 73, 74, 75, 76, 78, 79, 80, 86, 81)
							OR (s.ProductID = 3 AND s.EventType = 0)
							OR RefTable IN (1, 2))

				-- Get match info for Player Tips
				IF EXISTS (SELECT 1 FROM @Data WHERE SportType = 157)
				BEGIN
					UPDATE b14
					SET
						LeagueId = m14.leagueid,
						HomeId = m14.homeid,
						AwayId = m14.awayid,
						EventDate = m14.GlobalShowTime
					FROM @Data AS b14
						INNER JOIN dbo.match14 AS m14 WITH (NOLOCK) ON m14.matchid = b14.MatchId
					WHERE b14.SportType = 157
				END
			END
			-- Get related Bonus/Cash tickets
			IF EXISTS (SELECT 1 FROM @Data WHERE RefCode <> 0)
			BEGIN
				INSERT INTO @Data (
					BetType, TransId, BetId, RefNo, MatchCode, Race, EventDate, VirtualRate, IsShowOTExRate,
					SDiscount, ADiscount, Discount, HomeId, AwayId, SettleTime, Hdp1, Hdp2, Odds, FinalOdds,
					FinalOdds2, OddsType, Status, SettlementStatus, ComStatus, Stake, Actual_Stake, TransDate,
					BetTeam, SPositionTaking, MPositionTaking, APositionTaking, SPositionTaking2, MPositionTaking2,
					APositionTaking2, LiveIndicator, Modds, CustId, LiveHomeScore, LiveAwayScore, FinalHomeScore,
					FinalAwayScore, LeagueId, SportType, Ip, MatchId, IsNeutral, WinLost, Commission, SComm,
					AComm, Comm, AWinLost, MWinLost, SWinLost, ShowTime, WinLostDate, BetCheck, TransDesc,
					OddsSpread, OriginalBetType, BetdaqId, ExtraInfo, JackpotInfo, WalletType, RefCode,
					CurrencyId, SiteId, LeagueGroupId, DeviceType
				)
				SELECT
					b14.bettype,
					b14.transid,
					ISNULL(b14.betid, 0) AS BetId,
					b14.refno,
					m14.matchcode,
					'' AS Race,
					m14.GlobalShowTime AS EventDate,
					0 AS virtualrate,
					0 AS isShowOTExRate,
					b14.sdiscount,
					CASE
						WHEN b14.mrecommend = -4 THEN 0
						ELSE b14.adiscount
					END,
					CASE
						WHEN b14.recommend IN (-3, -4) THEN 0
						ELSE b14.discount
					END,
					m14.homeid,
					m14.awayid,
					ISNULL(b14.checktime,'') settleTime,
					b14.hdp1,
					b14.hdp2,
					b14.odds,
					0 AS finalodds,
					0 AS finalodds2,
					b14.oddstype,
					b14.status,
					0 AS SettlementStatus,
					CASE WHEN b14.comstatus = '1' THEN 1 ELSE 0 END AS comstatus,
					b14.stake,
					b14.actual_stake,
					b14.transdate,
					b14.betteam,
					b14.spositiontaking,
					b14.mpositiontaking,
					b14.apositiontaking,
					0 AS SPositionTaking2,
					0 AS MPositionTaking2,
					0 AS APositionTaking2,
					b14.liveindicator,
					b14.modds,
					b14.custid,
					b14.livehomescore,
					b14.liveawayscore,
					m14.finalhomescore,
					m14.finalawayscore,
					m14.leagueid,
					m14.sporttype,
					b14.ip,
					b14.matchid,
					ISNULL(m14.isNeutral, CONVERT(BIT,0)) AS IsNeutral,
					(b14.winlost - b14.actual_stake) AS winlost,
					b14.playercomm AS Commission,
					(b14.scomm - b14.acomm) AS scomm,
					(b14.acomm - b14.comm) AS acomm,
					(b14.comm - b14.playercomm) AS comm,
					b14.awinlost,
					b14.mwinlost,
					b14.swinlost,
					m14.showtime,
					b14.winlostdate,
					b14.BetCheck,
					ISNULL(b14.transdesc, '') AS TransDesc,
					ISNULL(b14.oddsspread, 0) AS OddsSpread,
					0 AS OriginalBetType,
					-1 AS BetdaqId,
					ISNULL(b14.ExtraInfo, '') AS ExtraInfo,
					'' AS JackpotInfo,
					ISNULL(b14.WalletType, 0) AS WalletType,
					ISNULL(b14.RefCode, 0) AS RefCode,
					b14.currency,
					'' AS SiteId,
					0 AS LeagueGroupID,
					b14.DeviceType
				FROM
					dbo.bettrans14 AS b14 WITH (NOLOCK)
					INNER JOIN @Data AS b114
						ON b14.custid = b114.CustId
						AND b14.winlostdate = b114.WinLostDate
						AND b14.RefCode = b114.RefCode
						AND b14.transid <> b114.TransId
					INNER JOIN dbo.match14 AS m14 WITH (NOLOCK) ON b14.matchid = m14.matchid
			END
		END

		-- Bettrans_bk
		ELSE IF @WinLostDate < @BalanceUpDay
		BEGIN
			-- Sportbooks, Number Game, Live Casino, Virtual Sports, Betradar Virtual Sports, Cash Out, Virtual Sports 3 (new), Virtual Sports 4
			IF EXISTS (SELECT TOP(1) 1 FROM @SportBettype WHERE EventType = 1 AND BetType = @BetType )
			BEGIN
				INSERT INTO @Data (
					BetType, TransId, BetId, RefNo, MatchCode, Race, EventDate, VirtualRate, IsShowOTExRate,
					SDiscount, ADiscount, Discount, HomeId, AwayId, SettleTime, Hdp1, Hdp2, Odds, FinalOdds,
					FinalOdds2, OddsType, Status, SettlementStatus, ComStatus, Stake, Actual_Stake, TransDate,
					BetTeam, SPositionTaking, MPositionTaking, APositionTaking, SPositionTaking2, MPositionTaking2,
					APositionTaking2, LiveIndicator, Modds, CustId, LiveHomeScore, LiveAwayScore, FinalHomeScore,
					FinalAwayScore, LeagueId, SportType, Ip, MatchId, IsNeutral, WinLost, Commission, SComm,
					AComm, Comm, AWinLost, MWinLost, SWinLost, ShowTime, WinLostDate, BetCheck, TransDesc,
					OddsSpread, OriginalBetType, BetdaqId, ExtraInfo, JackpotInfo, WalletType, RefCode,
					CurrencyId, SiteId, LeagueGroupId, DeviceType
				)
				SELECT
					bk.bettype,
					bk.transid,
					ISNULL(bk.BetID,0) AS BetId,
					bk.refno,
					m.matchcode,
					'' AS Race,
					CASE
						WHEN s.ProductID IN (1, 25) THEN m.GlobalShowTime
						ELSE m.eventdate
					END AS EventDate,
					0 AS virtualrate,
					0 AS isShowOTExRate,
					bk.sdiscount,
					CASE
						WHEN bk.mrecommend = -4 THEN 0
						ELSE bk.adiscount
					END,
					CASE
						WHEN bk.recommend IN (-3, -4) THEN 0
						ELSE bk.discount
					END,
					m.homeid,
					m.awayid,
					ISNULL(bk.checktime,'') settleTime,
					bk.hdp1,
					bk.hdp2,
					bk.odds,
					0 AS finalodds,
					0 AS finalodds2,
					bk.OddsType,
					bk.status,
					0 AS SettlementStatus,
					CASE WHEN bk.comstatus = '1' THEN 1 ELSE 0 END AS comstatus,
					bk.stake,
					bk.actual_stake,
					bk.transdate,
					bk.betteam,
					bk.spositiontaking,
					bk.mpositiontaking,
					bk.apositiontaking,
					0 AS SPositionTaking2,
					0 AS MPositionTaking2,
					0 AS APositionTaking2,
					bk.liveindicator,
					bk.modds,
					bk.custid,
					bk.livehomescore,
					bk.liveawayscore,
					m.finalhomescore,
					m.finalawayscore,
					m.leagueid,
					m.sporttype,
					dp.ip,
					bk.matchid,
					ISNULL(m.isNeutral, CONVERT(BIT,0)) AS IsNeutral,
					(bk.winlost-bk.actual_stake) AS winlost,
					bk.playercomm AS Commission,
					(bk.scomm - bk.acomm) AS scomm,
					(bk.acomm - bk.comm) AS acomm,
					(bk.comm - bk.playercomm) AS comm,
					bk.awinlost,
					bk.mwinlost,
					bk.swinlost,
					CASE
						WHEN s.ProductID IN (5, 27, 77) THEN CONVERT(NVARCHAR(50), m.kickofftime)
						ELSE m.showtime
					END AS ShowTime,
					bk.winlostdate,
					bk.BetCheck,
					ISNULL(bk.transdesc, '') AS TransDesc,
					ISNULL(bk.oddsspread, 0) AS OddsSpread,
					0 AS OriginalBetType,
					CASE
						WHEN s.ProductID = 1 THEN ISNULL(bk.betdaqid, -1)
						ELSE -1
					END AS BetdaqId,
					ISNULL(bk.ExtraInfo, '') AS ExtraInfo,
					'' AS JackpotInfo,
					CASE
						WHEN s.ProductID = 1 THEN ISNULL(bk.WalletType, 0)
						ELSE 0
					END AS WalletType,
					CASE
						WHEN s.ProductID = 1 THEN ISNULL(bk.RefCode, 0)
						ELSE 0
					END AS RefCode,
					bk.currency,
					'' AS SiteId,
					l.LeagueGroupID,
					bk.DeviceType
				FROM
					bodb_Archive.dbo.bettrans_bk AS bk WITH (NOLOCK)
					CROSS APPLY dbo.f_IP_Decompress(bk.Ip) AS dp
					INNER JOIN @SportBettype AS s ON s.BetType = bk.BetType
					INNER JOIN bodb_Archive.dbo.match_bk AS m WITH (NOLOCK) ON bk.matchid = m.matchid
					LEFT JOIN dbo.league AS l WITH (NOLOCK) ON l.leagueid = m.leagueid
				WHERE s.EventType = 1 AND bk.transid = @TransId

				-- Get more info for BetTrade tickets
				IF EXISTS (SELECT TOP(1) 1 FROM @Data WHERE SportType = 1 AND BetType = 901)
				BEGIN
					UPDATE bk
					SET bk.Odds = obk.odds,
						bk.Stake = obk.stake,
						bk.LiveHomeScore = obk.livehomescore,
						bk.LiveAwayScore = obk.liveawayscore,
						bk.BetId = obk.bettype
					FROM @Data AS bk
						INNER JOIN bodb_Archive.dbo.bettrans_bk AS obk WITH (NOLOCK) ON bk.RefNo = obk.transid
					WHERE bk.SportType = 1 AND bk.BetType = 901
				END

				IF EXISTS (SELECT TOP(1) 1 FROM @Data WHERE SportType = 1 AND BetType = 902)
				BEGIN
					UPDATE bk
					SET bk.Odds = obk.odds,
						bk.Stake = obk.stake,
						bk.LiveHomeScore = obk.livehomescore,
						bk.LiveAwayScore = obk.liveawayscore,
						bk.Comm = ISNULL(cbk.awinlost, 0),
						bk.BetId = obk.bettype
					FROM @Data AS bk
						INNER JOIN bodb_Archive.dbo.bettrans_bk AS obk WITH (NOLOCK) ON bk.RefNo = obk.transid
						LEFT JOIN bodb_Archive.dbo.bettrans_bk AS cbk WITH (NOLOCK)
							ON bk.RefNo = cbk.refno
							AND cbk.bettype = 903
							AND cbk.custid = @CustId
							AND cbk.winlostdate = @WinLostDate
					WHERE bk.SportType = 1 AND bk.BetType = 902
				END

				-- Get more info for CashOut tickets
				IF EXISTS (SELECT TOP(1) 1 FROM @Data WHERE BetType = 911)
				BEGIN
					UPDATE bk
					SET bk.Odds = obk.odds,
						bk.LiveIndicator = obk.liveindicator,
						bk.LiveHomeScore = obk.livehomescore,
						bk.LiveAwayScore = obk.liveawayscore,
						bk.OriginalBetType = obk.bettype,
						bk.BetdaqId = obk.transid
					FROM @Data AS bk
						INNER JOIN bodb_Archive.dbo.bettrans_bk AS obk WITH (NOLOCK) ON bk.RefNo = obk.transid
					WHERE bk.BetType = 911
				END

				IF EXISTS (SELECT TOP(1) 1 FROM @Data WHERE BetType = 912)
				BEGIN
					UPDATE bk
					SET bk.Odds = obk.odds,
						bk.LiveIndicator = obk.liveindicator,
						bk.LiveHomeScore = obk.livehomescore,
						bk.LiveAwayScore = obk.liveawayscore,
						bk.OriginalBetType = obk.bettype,
						bk.BetdaqId = obk.transid,
						bk.Stake = cobk.stake,
						bk.Comm = ISNULL(cbk.AWinLost, 0)
					FROM @Data AS bk
						INNER JOIN bodb_Archive.dbo.bettrans_bk AS cobk WITH (NOLOCK) ON bk.RefNo = cobk.transid
						INNER JOIN bodb_Archive.dbo.bettrans_bk AS obk WITH (NOLOCK) ON cobk.RefNo = obk.transid
						LEFT JOIN bodb_Archive.dbo.bettrans_bk AS cbk WITH (NOLOCK)
							ON bk.RefNo = cbk.refno
							AND cbk.bettype = 913
							AND cbk.custid = @CustId
							AND cbk.winlostdate = @WinLostDate
					WHERE bk.BetType = 912
				END
			END

			-- Bitcoin, Virtual Sports 5, vs6
			IF EXISTS (SELECT TOP(1) 1 FROM @SportBettype WHERE EventType = 5 AND BetType = @BetType )
			BEGIN
				INSERT INTO @Data (
					BetType, TransId, BetId, RefNo, MatchCode, Race, EventDate, VirtualRate, IsShowOTExRate,
					SDiscount, ADiscount, Discount, HomeId, AwayId, SettleTime, Hdp1, Hdp2, Odds, FinalOdds,
					FinalOdds2, OddsType, Status, SettlementStatus, ComStatus, Stake, Actual_Stake, TransDate,
					BetTeam, SPositionTaking, MPositionTaking, APositionTaking, SPositionTaking2, MPositionTaking2,
					APositionTaking2, LiveIndicator, Modds, CustId, LiveHomeScore, LiveAwayScore, FinalHomeScore,
					FinalAwayScore, LeagueId, SportType, Ip, MatchId, IsNeutral, WinLost, Commission, SComm,
					AComm, Comm, AWinLost, MWinLost, SWinLost, ShowTime, WinLostDate, BetCheck, TransDesc,
					OddsSpread, OriginalBetType, BetdaqId, ExtraInfo, JackpotInfo, WalletType, RefCode,
					CurrencyId, SiteId, LeagueGroupId, DeviceType
				)
				SELECT
					bk.bettype,
					bk.transid,
					ISNULL(bk.BetID,0) AS BetId,
					bk.refno,
					m.matchcode,
					'' AS Race,
					m.EndTime AS EventDate,
					0 AS virtualrate,
					0 AS isShowOTExRate,
					bk.sdiscount,
					CASE
						WHEN bk.mrecommend = -4 THEN 0
						ELSE bk.adiscount
					END,
					CASE
						WHEN bk.recommend IN (-3, -4) THEN 0
						ELSE bk.discount
					END,
					m.homeid,
					m.awayid,
					ISNULL(bk.checktime,'') settleTime,
					bk.hdp1,
					bk.hdp2,
					bk.odds,
					0 AS finalodds,
					0 AS finalodds2,
					bk.OddsType,
					bk.status,
					0 AS SettlementStatus,
					0 AS comstatus,
					bk.stake,
					bk.actual_stake,
					bk.transdate,
					bk.betteam,
					bk.spositiontaking,
					bk.mpositiontaking,
					bk.apositiontaking,
					0 AS SPositionTaking2,
					0 AS MPositionTaking2,
					0 AS APositionTaking2,
					bk.liveindicator,
					bk.modds,
					bk.custid,
					bk.livehomescore,
					bk.liveawayscore,
					m.finalhomescore,
					m.finalawayscore,
					m.league3rdid,
					m.sporttype,
					dp.ip,
					bk.matchid,
					CONVERT(BIT,0) AS IsNeutral,
					(bk.winlost-bk.actual_stake) AS winlost,
					bk.playercomm AS Commission,
					(bk.scomm - bk.acomm) AS scomm,
					(bk.acomm - bk.comm) AS acomm,
					(bk.comm - bk.playercomm) AS comm,
					bk.awinlost,
					bk.mwinlost,
					bk.swinlost,
					CONVERT(NVARCHAR(50), m.StartTime) AS ShowTime,
					bk.winlostdate,
					bk.BetCheck,
					ISNULL(bk.transdesc, '') AS TransDesc,
					ISNULL(bk.oddsspread, 0) AS OddsSpread,
					0 AS OriginalBetType,
					-1 AS BetdaqId,
					ISNULL(bk.ExtraInfo, '') AS ExtraInfo,
					'' AS JackpotInfo,
					0 AS WalletType,
					0 AS RefCode,
					bk.currency,
					'' AS SiteId,
					0 AS LeagueGroupID,
					bk.DeviceType
				FROM
					bodb_Archive.dbo.bettrans_bk AS bk WITH (NOLOCK)
					CROSS APPLY dbo.f_IP_Decompress(bk.Ip) AS dp
					INNER JOIN @SportBettype AS s ON s.BetType = bk.BetType
					INNER JOIN bodb_Archive.dbo.match3rd_bk AS m WITH (NOLOCK) ON bk.matchid = m.match3rdid
				WHERE s.EventType = 5 AND bk.transid = @TransId

			END

			-- Mix Parlay, Combination Mix Parlay, Mix Parlay (Betradar Virtual Sports), VS3, Mix Parlay (VS4), , Mix Parlay (VS5)
			IF @BetType IN (9, 29, 2798, 2799, 10449, 11099)
			BEGIN
				INSERT INTO @Data (
					BetType, TransId, BetId, RefNo, MatchCode, Race, EventDate, VirtualRate, IsShowOTExRate,
					SDiscount, ADiscount, Discount, HomeId, AwayId, SettleTime, Hdp1, Hdp2, Odds, FinalOdds,
					FinalOdds2, OddsType, Status, SettlementStatus, ComStatus, Stake, Actual_Stake, TransDate,
					BetTeam, SPositionTaking, MPositionTaking, APositionTaking, SPositionTaking2, MPositionTaking2,
					APositionTaking2, LiveIndicator, Modds, CustId, LiveHomeScore, LiveAwayScore, FinalHomeScore,
					FinalAwayScore, LeagueId, SportType, Ip, MatchId, IsNeutral, WinLost, Commission, SComm,
					AComm, Comm, AWinLost, MWinLost, SWinLost, ShowTime, WinLostDate, BetCheck, TransDesc,
					OddsSpread, OriginalBetType, BetdaqId, ExtraInfo, JackpotInfo, WalletType, RefCode,
					CurrencyId, SiteId, LeagueGroupId, DeviceType
				)
				SELECT
					bk.bettype,
					bk.transid,
					ISNULL(bk.betid, 0) AS BetId,
					bk.refno,
					'' AS MatchCode,
					'' AS Race,
					'' AS EventDate,
					0 AS VirtualRate,
					0 AS IsShowOTExRate,
					bk.sdiscount,
					CASE
						WHEN bk.mrecommend = -4 THEN 0
						ELSE bk.adiscount
					END,
					CASE
						WHEN bk.recommend IN (-3, -4) THEN 0
						ELSE bk.discount
					END,
					0 AS HomeId,
					0 AS AwayId,
					'' AS SettleTime,
					bk.hdp1,
					bk.hdp2,
					bk.odds,
					0 AS FinalOdds,
					0 AS FinalOdds2,
					0 AS OddsType,
					bk.status,
					0 AS SettlementStatus,
					CASE WHEN bk.comstatus = '1' THEN 1 ELSE 0 END AS comstatus,
					bk.stake,
					bk.actual_stake,
					bk.transdate,
					bk.betteam,
					bk.spositiontaking,
					bk.mpositiontaking,
					bk.apositiontaking,
					0 AS SPositionTaking2,
					0 AS MPositionTaking2,
					0 AS APositionTaking2,
					0 AS LiveIndicator,
					bk.modds,
					bk.custid,
					bk.livehomescore,
					bk.liveawayscore,
					0 AS FinalHomeScore,
					0 AS FinalAwayScore,
					0 AS LeagueId,
					0 AS SportType,
					dp.ip,
					0 AS MatchId,
					CONVERT(BIT, 0) AS IsNeutral,
					(bk.winlost - bk.actual_stake) AS WinLost,
					bk.playercomm AS Commission,
					(bk.scomm - bk.acomm) AS SComm,
					(bk.acomm - bk.comm) AS AComm,
					(bk.comm - bk.playercomm) AS Comm,
					bk.awinlost,
					bk.mwinlost,
					bk.swinlost,
					'' AS ShowTime,
					bk.winlostdate,
					bk.betcheck,
					IIF(bk.bettype = 29 AND bk.oddsspread = 3, ISNULL(bk.transdesc, ''), '') AS TransDesc,
					ISNULL(bk.oddsspread, 0) AS OddsSpread,
					0 AS OriginalBetType,
					-1 AS BetdaqId,
					bk.ExtraInfo,
					'' AS JackpotInfo,
					0 AS WalletType,
					0 AS RefCode,
					bk.currency,
					'' AS SiteId,
					0 AS LeagueGroupID,
					bk.DeviceType
				FROM bodb_Archive.dbo.bettrans_bk AS bk WITH (NOLOCK)
				CROSS APPLY dbo.f_IP_Decompress(bk.Ip) AS dp
				WHERE bk.transid = @TransId AND bk.bettype IN (9, 29, 2798, 2799, 10449, 11099)
			END

			-- Outright
			IF @BetType = 10
			BEGIN
				INSERT INTO @Data (
					BetType, TransId, BetId, RefNo, MatchCode, Race, EventDate, VirtualRate, IsShowOTExRate,
					SDiscount, ADiscount, Discount, HomeId, AwayId, SettleTime, Hdp1, Hdp2, Odds, FinalOdds,
					FinalOdds2, OddsType, Status, SettlementStatus, ComStatus, Stake, Actual_Stake, TransDate,
					BetTeam, SPositionTaking, MPositionTaking, APositionTaking, SPositionTaking2, MPositionTaking2,
					APositionTaking2, LiveIndicator, Modds, CustId, LiveHomeScore, LiveAwayScore, FinalHomeScore,
					FinalAwayScore, LeagueId, SportType, Ip, MatchId, IsNeutral, WinLost, Commission, SComm,
					AComm, Comm, AWinLost, MWinLost, SWinLost, ShowTime, WinLostDate, BetCheck, TransDesc,
					OddsSpread, OriginalBetType, BetdaqId, ExtraInfo, JackpotInfo, WalletType, RefCode,
					CurrencyId, SiteId, LeagueGroupId, DeviceType
				)
				SELECT
					bk.bettype,
					bk.transid,
					ISNULL(bk.BetID,0) AS BetId,
					bk.refno,
					odds.matchcode,
					odds.groupmatch AS race,
					odds.eventdate,
					0 AS virtualrate,
					0 AS isShowOTExRate,
					bk.sdiscount,
					CASE
						WHEN bk.mrecommend = -4 THEN 0
						ELSE bk.adiscount
					END,
					CASE
						WHEN bk.recommend IN (-3, -4) THEN 0
						ELSE bk.discount
					END,
					0 AS homeid,
					odds.teamid AS awayid,
					'' settleTime, 
					bk.hdp1,
					bk.hdp2,
					bk.odds,
					0 AS finalodds,
					0 AS finalodds2,
					bk.oddstype AS OddsType,
					bk.status,
					0 AS SettlementStatus,
					CASE WHEN bk.comstatus = '1' THEN 1 ELSE 0 END AS comstatus,
					bk.stake,
					bk.actual_stake,
					bk.transdate,
					bk.betteam,
					bk.spositiontaking,
					bk.mpositiontaking,
					bk.apositiontaking,
					0 AS SPositionTaking2,
					0 AS MPositionTaking2,
					0 AS APositionTaking2,
					bk.liveindicator,
					bk.modds,
					bk.custid,
					bk.livehomescore,
					bk.liveawayscore,
					0,
					0,
					odds.leagueid,
					l.sporttype,
					dp.ip,
					bk.matchid,
					CONVERT(BIT,0) AS IsNeutral,
					(bk.winlost-bk.actual_stake) AS winlost,
					bk.playercomm AS Commission,
					(bk.scomm - bk.acomm) AS scomm,
					(bk.acomm - bk.comm) AS acomm,
					(bk.comm - bk.playercomm) AS comm,
					bk.awinlost,
					bk.mwinlost,
					bk.swinlost,
					'' AS showtime,
					bk.winlostdate,
					bk.BetCheck,
					'' AS TransDesc,
					0 AS OddsSpread,
					0 AS OriginalBetType,
					-1 AS BetdaqId,
					'' AS ExtraInfo,
					'' AS JackpotInfo,
					0 AS WalletType,
					0 AS RefCode,
					bk.currency,
					'' AS SiteId,
					0 AS LeagueGroupID,
					bk.DeviceType
				FROM bodb_Archive.dbo.bettrans_bk AS bk WITH (NOLOCK)
					CROSS APPLY dbo.f_IP_Decompress(bk.Ip) AS dp
					INNER JOIN bodb_Archive.dbo.outright_bk AS odds WITH (NOLOCK) ON bk.matchid = odds.orid
					INNER JOIN dbo.league AS l WITH (NOLOCK) ON odds.leagueid = l.leagueid
				WHERE bk.bettype = 10
					AND bk.transid = @TransId
			END

			-- Virtual Horse Racing, VS2 Racing, VS7
			IF EXISTS(SELECT TOP(1) 1 FROM @SportBettype WHERE ProductID IN (5, 27, 106) AND EventType = 3 AND BetType = @BetType)
			BEGIN
				INSERT INTO @Data (
					BetType, TransId, BetId, RefNo, MatchCode, Race, EventDate, VirtualRate, IsShowOTExRate,
					SDiscount, ADiscount, Discount, HomeId, AwayId, SettleTime, Hdp1, Hdp2, Odds, FinalOdds,
					FinalOdds2, OddsType, Status, SettlementStatus, ComStatus, Stake, Actual_Stake, TransDate,
					BetTeam, SPositionTaking, MPositionTaking, APositionTaking, SPositionTaking2, MPositionTaking2,
					APositionTaking2, LiveIndicator, Modds, CustId, LiveHomeScore, LiveAwayScore, FinalHomeScore,
					FinalAwayScore, LeagueId, SportType, Ip, MatchId, IsNeutral, WinLost, Commission, SComm,
					AComm, Comm, AWinLost, MWinLost, SWinLost, ShowTime, WinLostDate, BetCheck, TransDesc,
					OddsSpread, OriginalBetType, BetdaqId, ExtraInfo, JackpotInfo, WalletType, RefCode,
					CurrencyId, SiteId, LeagueGroupId, DeviceType
				)
				SELECT 
					bk.bettype,
					bk.transid,
					'' AS BetId,
					bk.refno,
					'' AS matchcode, --Horse Number
					bk.oddsid AS Race, --Outright ID
					'' eventdate,
					0 AS virtualrate,
					0 AS isShowOTExRate,
					bk.sdiscount,
					CASE
						WHEN bk.mrecommend = -4 THEN 0
						ELSE bk.adiscount
					END,
					CASE
						WHEN bk.recommend IN (-3, -4) THEN 0
						ELSE bk.discount
					END,
					0 AS homeID,
					0 AS awayID,
					'' settleTime,
					bk.hdp1,
					bk.hdp2,
					bk.odds,
					0 AS finalodds,
					0 AS finalodds2,
					bk.OddsType,
					bk.status,
					0 AS SettlementStatus,
					CASE WHEN bk.comstatus = '1' THEN 1 ELSE 0 END AS comstatus,
					bk.stake,
					bk.actual_stake,
					bk.transdate,
					bk.betteam AS betteam, 
					CASE WHEN bk.bettype = 1233 THEN bmk.spositiontaking ELSE bk.spositiontaking END,
					CASE WHEN bk.bettype = 1233 THEN bmk.mpositiontaking ELSE bk.mpositiontaking END,
					CASE WHEN bk.bettype = 1233 THEN bmk.apositiontaking ELSE bk.apositiontaking END,
					CASE WHEN bk.bettype = 1233 THEN bmk.spositiontaking2 ELSE 0 END,
					CASE WHEN bk.bettype = 1233 THEN bmk.mpositiontaking2 ELSE 0 END,
					CASE WHEN bk.bettype = 1233 THEN bmk.apositiontaking2 ELSE 0 END,
					0 liveindicator,
					bk.modds,
					bk.custid,
					bk.livehomescore, 
					bk.liveawayscore, 
					0 finalhomescore, 
					0 finalawayscore, 
					r.leagueid,
					r.sporttype,
					dp.ip,
					bk.matchid,
					CONVERT (BIT, 0) AS IsNeutral,
					(bk.winlost-bk.actual_stake) AS winlost,
					bk.playercomm AS Commission,
					(bk.scomm - bk.acomm) AS scomm,
					(bk.acomm - bk.comm) AS acomm,
					(bk.comm - bk.playercomm) AS comm,
					bk.awinlost,
					bk.mwinlost,
					bk.swinlost,
					'' AS ShowTime,
					bk.winlostdate,
					bk.BetCheck,
					bk.TransDesc AS TransDesc,
						0 AS OddsSpread,
					0 AS OriginalBetType,
					-1 AS BetdaqId,
					bk.ExtraInfo,
					'' AS JackpotInfo,
					0 AS WalletType,
					0 AS RefCode,
					bk.currency,
					'' AS SiteId,
					0 AS LeagueGroupID,
					bk.DeviceType
				FROM 
					bodb_Archive.dbo.bettrans_bk AS bk WITH (NOLOCK) 
					CROSS APPLY dbo.f_IP_Decompress(bk.Ip) AS dp
					INNER JOIN bodb_Archive.dbo.VSRaceInfo_bk AS r WITH (NOLOCK) ON r.EventID = bk.matchid
					INNER JOIN @SportBettype AS s ON s.BetType = bk.BetType
					LEFT JOIN (
						SELECT
							t.refno,
							t.apositiontaking,
							t.mpositiontaking,
							t.spositiontaking,
							f.apositiontaking apositiontaking2,
							f.mpositiontaking mpositiontaking2,
							f.spositiontaking spositiontaking2
						FROM bodb_archive.dbo.bettransm AS t WITH (NOLOCK)
							INNER JOIN bodb_archive.dbo.bettransm AS f WITH (NOLOCK) ON t.refno = f.refno
						WHERE t.bettype = 1231 AND f.bettype = 1232 
						) bmk ON bk.refno = bmk.refno
				WHERE bk.transid = @TransId
					AND s.EventType = 3
			END

			-- RNG Casino Single Wallet, AG Casino Single Wallet, AllBet, Voidbridge, NG2, Pragmatic Casino, Card Club, NPH Promotion
			-- Spadegaming, SA Gaming, Sexy Gaming, Saba.club, IBCBet Live Casino, BBIN, RNG War, ION, PG Soft, Joker, WM, Big Gaming, MaxGame
			-- Happy 5 Linked Games(Number Game), Habanero, CG, Sports Lottery, PP Live Casino, VGaming, AdvantPlay, AdvantPlay Mini, FGG, SEAL Entertainment, MG RNG Casino, Player Tips,
			-- Jili, YeeBet, WE, Live22, UU Slots, Saba xD, Saba Coins
			IF EXISTS (SELECT TOP(1) 1 FROM @SportBettype
						WHERE Bettype = @BetType 
							AND (ProductID IN (11, 21, 22, 23, 32, 34, 36, 37, 39, 42, 45, 46, 47, 50, 51, 52, 55, 56, 57, 60, 61, 62, 63, 65, 66, 67, 68, 70, 72, 73, 74, 75, 76, 78, 79, 80, 86, 81)
								OR (ProductID = 6 AND SubProduct <> '')
								OR (ProductID = 3 AND EventType = 0)
								OR RefTable IN (1, 2)))
			BEGIN
				INSERT INTO @Data (
					BetType, TransId, BetId, RefNo, MatchCode, Race, EventDate, VirtualRate, IsShowOTExRate,
					SDiscount, ADiscount, Discount, HomeId, AwayId, SettleTime, Hdp1, Hdp2, Odds, FinalOdds,
					FinalOdds2, OddsType, Status, SettlementStatus, ComStatus, Stake, Actual_Stake, TransDate,
					BetTeam, SPositionTaking, MPositionTaking, APositionTaking, SPositionTaking2, MPositionTaking2,
					APositionTaking2, LiveIndicator, Modds, CustId, LiveHomeScore, LiveAwayScore, FinalHomeScore,
					FinalAwayScore, LeagueId, SportType, Ip, MatchId, IsNeutral, WinLost, Commission, SComm,
					AComm, Comm, AWinLost, MWinLost, SWinLost, ShowTime, WinLostDate, BetCheck, TransDesc,
					OddsSpread, OriginalBetType, BetdaqId, ExtraInfo, JackpotInfo, WalletType, RefCode,
					CurrencyId, SiteId, LeagueGroupId, DeviceType
				)
				SELECT
					bk.bettype,
					bk.transid,
					ISNULL(bk.betid, 0) AS BetId,
					bk.refno,
					'' AS matchcode,
					'' AS Race,
					'' AS eventdate,
					0 AS virtualrate,
					0 AS isShowOTExRate,
					bk.sdiscount,
					CASE
						WHEN bk.mrecommend = -4 THEN 0
						ELSE bk.adiscount
					END,
					CASE
						WHEN bk.recommend IN (-3, -4) THEN 0
						ELSE bk.discount
					END,
					0 AS homeid,
					0 AS awayid,
					'' AS settleTime,
					CASE
						WHEN s.ProductId = 23 THEN bk.hdp1
						ELSE 0
					END AS hdp1,
					CASE
						WHEN s.ProductId = 23 THEN bk.hdp2
						ELSE 0
					END AS hdp2,
					CASE
						WHEN s.ProductId IN (3, 6, 23, 32, 36, 42, 63, 66) THEN bk.odds
						ELSE 0
					END AS odds,
					0 AS finalodds,
					0 AS finalodds2,
					0 AS OddsType,
					bk.status,
					0 AS SettlementStatus,
					'' AS comstatus,
					bk.stake,
					bk.actual_stake,
					bk.transdate,
					'' AS betteam,
					bk.spositiontaking,
					bk.mpositiontaking,
					bk.apositiontaking,
					0 AS SPositionTaking2,
					0 AS MPositionTaking2,
					0 AS APositionTaking2,
					0 AS liveindicator,
					0 AS modds,
					bk.custid,
					CASE
						WHEN s.ProductId = 23 THEN bk.livehomescore
						ELSE 0
					END AS livehomescore,
					0 AS LiveAwayScore,
					0 AS finalhomescore,
					0 AS finalawayscore,
					0 AS leagueid,
					CASE
						WHEN s.ProductID = 6 AND s.SubProduct <> '' THEN bk.matchid
						WHEN s.ProductID = 11 THEN 250
						WHEN s.ProductID = 21 THEN 211
						WHEN s.ProductID = 22 THEN 212
						WHEN s.ProductID = 23 AND s.Bettype BETWEEN 2501 AND 2539 THEN 213
						WHEN s.ProductID = 23 AND s.Bettype BETWEEN 2541 AND 2579 THEN 214
						WHEN s.ProductID = 23 AND s.Bettype BETWEEN 2581 AND 2619 THEN 215
						WHEN s.ProductID = 23 AND s.Bettype BETWEEN 2621 AND 2659 THEN 216
						WHEN s.ProductID = 23 AND s.Bettype BETWEEN 2681 AND 2699 THEN 218
						WHEN s.ProductID = 32 THEN 248
						WHEN s.ProductID IN (3, 34, 36, 37, 39, 42, 45, 46, 47, 50, 51, 52, 55, 56, 57, 60, 61, 62, 63, 65, 66, 67, 68, 70, 72, 73, 74, 75, 76, 78, 79, 80, 86, 81) THEN bk.matchid
						WHEN s.RefTable IN (1, 2) THEN bk.matchid
						ELSE 0
					END AS SportType,
					dp.ip,
					CASE
						WHEN s.ProductId = 23 THEN bk.betdaqid
						WHEN s.ProductID = 74 THEN ISNULL(CAST(('<xml>' + bk.ExtraInfo + '</xml>') AS XML).value('data(/xml/p74/@m)[1]','INT'), 0)
						ELSE 0
					END AS MatchId,
					CONVERT(BIT, 0) AS IsNeutral,
					(bk.winlost - bk.actual_stake) AS winlost,
					bk.playercomm AS Commission,
					(bk.scomm - bk.acomm) AS scomm,
					(bk.acomm - bk.comm) AS acomm,
					(bk.comm - bk.playercomm) AS comm,
					bk.awinlost,
					bk.mwinlost,
					bk.swinlost,
					'' AS showtime,
					bk.winlostdate,
					CASE 
						WHEN s.ProductId IN (3, 63) THEN bk.betcheck
						ELSE ''
					END AS BetCheck,
					CASE
						WHEN s.ProductID = 6 AND s.SubProduct <> '' THEN bk.transdesc
						WHEN s.ProductID IN (3, 22, 23, 32, 34, 36, 55, 56, 61, 62, 63, 67, 68, 72) THEN bk.transdesc
						ELSE ''
					END AS TransDesc,
					CASE
						WHEN pj.ProductId IS NOT NULL THEN ISNULL(bk.oddsspread, 0)
						ELSE 0
					END AS OddsSpread,
					0 AS OriginalBetType,
					-1 AS BetdaqId,
					ISNULL(bk.ExtraInfo, '') AS ExtraInfo,
					'' AS JackpotInfo,
					0 AS WalletType,
					0 AS RefCode,
					bk.currency,
					CASE 
						WHEN s.ProductId = 3 AND s.EventType = 0 THEN CONVERT(VARCHAR(20), bk.betdaqid)
						WHEN s.ProductId = 63 THEN CONVERT(VARCHAR(20), bk.betdaqid)
						ELSE '' 
					END AS SiteId,
					0 AS LeagueGroupID,
					bk.DeviceType
				FROM bodb_Archive.dbo.bettrans_bk AS bk WITH (NOLOCK)
					CROSS APPLY dbo.f_IP_Decompress(bk.Ip) AS dp
					INNER JOIN @SportBettype AS s ON s.Bettype = bk.bettype
					LEFT JOIN @ProductJackpot AS pj ON s.ProductId = pj.ProductId
				WHERE bk.transid = @TransID
					AND (s.ProductID IN (11, 21, 22, 23, 32, 34, 36, 37, 39, 42, 45, 46, 47, 50, 51, 52, 55, 56, 57, 60, 61, 62, 63, 65, 66, 67, 68, 70, 72, 73, 74, 75, 76, 78, 79, 80, 86, 81)
						OR (s.ProductID = 6 AND s.SubProduct <> '')
						OR (s.ProductID = 3 AND s.EventType = 0)
						OR RefTable IN (1, 2))

				-- Get match info for Player Tips
				IF EXISTS (SELECT 1 FROM @Data WHERE SportType = 157)
				BEGIN
					UPDATE bk
					SET
						LeagueId = m.leagueid,
						HomeId = m.homeid,
						AwayId = m.awayid,
						EventDate = m.GlobalShowTime
					FROM @Data AS bk
						INNER JOIN bodb_Archive.dbo.match_bk AS m WITH (NOLOCK) ON m.matchid = bk.MatchId
					WHERE bk.SportType = 157
				END
			END

			-- Get related Bonus/Cash tickets
			IF EXISTS (SELECT 1 FROM @Data WHERE RefCode <> 0)
			BEGIN
				INSERT INTO @Data (
					BetType, TransId, BetId, RefNo, MatchCode, Race, EventDate, VirtualRate, IsShowOTExRate,
					SDiscount, ADiscount, Discount, HomeId, AwayId, SettleTime, Hdp1, Hdp2, Odds, FinalOdds,
					FinalOdds2, OddsType, Status, SettlementStatus, ComStatus, Stake, Actual_Stake, TransDate,
					BetTeam, SPositionTaking, MPositionTaking, APositionTaking, SPositionTaking2, MPositionTaking2,
					APositionTaking2, LiveIndicator, Modds, CustId, LiveHomeScore, LiveAwayScore, FinalHomeScore,
					FinalAwayScore, LeagueId, SportType, Ip, MatchId, IsNeutral, WinLost, Commission, SComm,
					AComm, Comm, AWinLost, MWinLost, SWinLost, ShowTime, WinLostDate, BetCheck, TransDesc,
					OddsSpread, OriginalBetType, BetdaqId, ExtraInfo, JackpotInfo, WalletType, RefCode,
					CurrencyId, SiteId, LeagueGroupId, DeviceType
				)
				SELECT
					bk.bettype,
					bk.transid,
					ISNULL(bk.betid, 0) AS BetId,
					bk.refno,
					m.matchcode,
					'' AS Race,
					m.GlobalShowTime AS EventDate,
					0 AS virtualrate,
					0 AS isShowOTExRate,
					bk.sdiscount,
					CASE
						WHEN bk.mrecommend = -4 THEN 0
						ELSE bk.adiscount
					END,
					CASE
						WHEN bk.recommend IN (-3, -4) THEN 0
						ELSE bk.discount
					END,
					m.homeid,
					m.awayid,
					ISNULL(bk.checktime,'') settleTime,
					bk.hdp1,
					bk.hdp2,
					bk.odds,
					0 AS finalodds,
					0 AS finalodds2,
					bk.oddstype,
					bk.status,
					0 AS SettlementStatus,
					CASE WHEN bk.comstatus = '1' THEN 1 ELSE 0 END AS comstatus,
					bk.stake,
					bk.actual_stake,
					bk.transdate,
					bk.betteam,
					bk.spositiontaking,
					bk.mpositiontaking,
					bk.apositiontaking,
					0 AS SPositionTaking2,
					0 AS MPositionTaking2,
					0 AS APositionTaking2,
					bk.liveindicator,
					bk.modds,
					bk.custid,
					bk.livehomescore,
					bk.liveawayscore,
					m.finalhomescore,
					m.finalawayscore,
					m.leagueid,
					m.sporttype,
					dp.ip,
					bk.matchid,
					ISNULL(m.isNeutral, CONVERT(BIT,0)) AS IsNeutral,
					(bk.winlost - bk.actual_stake) AS winlost,
					bk.playercomm AS Commission,
					(bk.scomm - bk.acomm) AS scomm,
					(bk.acomm - bk.comm) AS acomm,
					(bk.comm - bk.playercomm) AS comm,
					bk.awinlost,
					bk.mwinlost,
					bk.swinlost,
					m.showtime,
					bk.winlostdate,
					bk.BetCheck,
					ISNULL(bk.transdesc, '') AS TransDesc,
					ISNULL(bk.oddsspread, 0) AS OddsSpread,
					0 AS OriginalBetType,
					-1 AS BetdaqId,
					ISNULL(bk.ExtraInfo, '') AS ExtraInfo,
					'' AS JackpotInfo,
					ISNULL(bk.WalletType, 0) AS WalletType,
					ISNULL(bk.RefCode, 0) AS RefCode,
					bk.currency,
					'' AS SiteId,
					0 AS LeagueGroupID,
					bk.DeviceType
				FROM
					bodb_Archive.dbo.bettrans_bk AS bk WITH (NOLOCK)
					CROSS APPLY dbo.f_IP_Decompress(bk.Ip) AS dp
					INNER JOIN @Data AS bk1
						ON bk.custid = bk1.CustId
						AND bk.winlostdate = bk1.WinLostDate
						AND bk.RefCode = bk1.RefCode
						AND bk.transid <> bk1.TransId
					INNER JOIN bodb_Archive.dbo.match_bk AS m WITH (NOLOCK) ON bk.matchid = m.matchid
			END
		END
	END

	-- Get original odds for Mix Parlay and final odds, boost rate for Mix Parlay Boost Bonus
	IF EXISTS (SELECT 1 FROM @Data WHERE BetType = 29 AND BetTeam = '1')
		AND @WinLostDate >= @BalanceUpDay
	BEGIN
		-- Running/Waiting
		DECLARE @ParlayData TABLE (
			RefNo		BIGINT,
			BoostRate	MONEY)

		INSERT INTO @ParlayData(RefNo, BoostRate)
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
		INSERT INTO @TmpParlayData (RefNo, Odds, MOdds)
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
		INSERT INTO @TmpParlayData(RefNo, Odds, MOdds)
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
			b.TransDesc = IIF(b.OddsSpread = 3, b.TransDesc, CONVERT(VARCHAR(20), ISNULL(bpr.ExtraValue, '')))
		FROM @Data AS b
			INNER JOIN dbo.BetParlayResult AS bpr WITH (NOLOCK) ON bpr.RefNo = b.RefNo
		WHERE b.BetType = 29
			AND b.BetTeam = '1'
			AND b.Status NOT IN ('Running', 'Waiting')
	END

	IF EXISTS (SELECT 1 FROM @Data WHERE BetType = 29 AND BetTeam = '1')
		AND @WinLostDate < @BalanceUpDay
	BEGIN
		UPDATE b
		SET
			b.Odds = bpr.Odds,
			b.Modds = bpr.mOdds,
			b.TransDesc = IIF(b.OddsSpread = 3,b.TransDesc, CONVERT(VARCHAR(20), ISNULL(bpr.ExtraValue, '')))
		FROM @Data AS b
			INNER JOIN bodb_Archive.dbo.BetParlayResult AS bpr WITH (NOLOCK) ON bpr.RefNo = b.RefNo
		WHERE b.BetType = 29 AND b.BetTeam = '1'
	END
	
	-- Don't display Cash text for ticket from Cash Wallet only
	UPDATE @Data
	SET WalletType = 0
	WHERE WalletType = 2 AND RefCode = 0

	-- Display Cash/Bonus text for ticket from multiple wallets
	UPDATE @Data
	SET RefCode = 0
	WHERE RefCode <> 0

	-- BettransRnG tables
	SET @WinLostDate = NULL
	SET @CustId = NULL

	IF @ExcludeBettrans = 0
	BEGIN
		-- bettransRnG
		SELECT TOP(1)
			@TransId = b.transid,
			@BetType = b.gameID,
			@WinLostDate = b.winlostdate,
			@CustId = b.custid
		FROM dbo.bettransRnG AS b WITH (NOLOCK)
			INNER JOIN @SportBettype AS sp ON b.gameID = sp.bettype
		WHERE b.transid = @RefNo
	END

	-- bettransRnG14
	IF @WinLostDate IS NULL
	BEGIN
		SELECT TOP(1)
			@TransId = b.transid,
			@BetType = b.gameID,
			@WinLostDate = b.winlostdate,
			@CustId = b.custid
		FROM dbo.bettransRnG14 AS b WITH (NOLOCK)
			INNER JOIN @SportBettype AS sp ON b.gameID = sp.bettype
		WHERE b.transid = @RefNo
	END

	IF @WinLostDate IS NOT NULL
		AND NOT EXISTS ( SELECT 1
						FROM dbo.customer AS c WITH (NOLOCK)
							INNER JOIN dbo.customer AS a WITH (NOLOCK) ON c.recommend = a.custid
							WHERE c.custid = @CustId
								AND a.site IN (SELECT Site FROM @DeniedSite))
		AND NOT EXISTS ( SELECT 1
						FROM dbo.customer AS c WITH (NOLOCK)
						WHERE c.custid = @CustId
							AND c.currency IN (SELECT ExchangeId FROM @DeniedCurrency))
	BEGIN
		-- bettransRnG
		IF @WinLostDate > @MoveBetsDay
		BEGIN
			-- RNG Casino Single Wallet, Macau Games, Pragmatic Casino, Card Club, Spadegaming, Saba.club, RNG War, PG Soft, Joker, MaxGame, Habanero, CG, VGaming
			-- AdvantPlay, AdvantPlay Mini, SEAL Entertainment, MG RNG Casino, Jili, Live22, UU Slots, Saba xD
			IF EXISTS (	SELECT TOP(1) 1 FROM @SportBettype
						WHERE Bettype = @BetType
							AND (ProductID IN (22, 32, 34, 36, 42, 50, 55, 56, 60, 61, 62, 66, 67, 68, 72, 73, 75, 78, 79, 86)
								OR (ProductID = 6 AND SubProduct <> '')
								OR RefTable = 1))
			BEGIN
				INSERT INTO @Data (
					BetType, TransId, BetId, RefNo, MatchCode, Race, EventDate, VirtualRate, IsShowOTExRate,
					SDiscount, ADiscount, Discount, HomeId, AwayId, SettleTime, Hdp1, Hdp2, Odds, FinalOdds,
					FinalOdds2, OddsType, Status, SettlementStatus, ComStatus, Stake, Actual_Stake, TransDate,
					BetTeam, SPositionTaking, MPositionTaking, APositionTaking, SPositionTaking2, MPositionTaking2,
					APositionTaking2, LiveIndicator, Modds, CustId, LiveHomeScore, LiveAwayScore, FinalHomeScore,
					FinalAwayScore, LeagueId, SportType, Ip, MatchId, IsNeutral, WinLost, Commission, SComm,
					AComm, Comm, AWinLost, MWinLost, SWinLost, ShowTime, WinLostDate, BetCheck, TransDesc,
					OddsSpread, OriginalBetType, BetdaqId, ExtraInfo, JackpotInfo, WalletType, RefCode,
					CurrencyId, SiteId, LeagueGroupId, DeviceType
				)
				SELECT
					b.gameID AS BetType,
					b.transid,
					0 AS BetId,
					b.refno,
					CASE
						WHEN s.productID IN (42) THEN ISNULL(b.SiteID, '')
						ELSE b.Additional
					END AS MatchCode,
					'' AS Race,
					CASE
						WHEN s.productID IN (60) THEN b.Transdate3rd
						ELSE ''
					END AS EventDate,
					0 AS virtualrate,
					0 AS isShowOTExRate,
					b.sdiscount,
					CASE
						WHEN b.mrecommend = -4 THEN 0
						ELSE b.adiscount
					END,
					CASE
						WHEN b.recommend IN (-3, -4) THEN 0
						ELSE b.discount
					END,
					0 AS homeid,
					0 AS awayid,
					'' AS settleTime,
					0 AS hdp1,
					0 AS hdp2,
					CASE
						WHEN pj.ProductId IS NOT NULL AND b.statusID IN (111, 112, 113) THEN ISNULL(b.ContributionRate, 0)
						ELSE b.odds
					END AS Odds,
					0 AS finalodds,
					0 AS finalodds2,
					0 AS OddsType,
					b.status,
					0 AS SettlementStatus,
					'' AS comstatus,
					b.stake,
					b.actual_stake,
					b.transdate,
					b.GameId3rd AS betteam,
					b.spositiontaking,
					b.mpositiontaking,
					b.apositiontaking,
					0 AS SPositionTaking2,
					0 AS MPositionTaking2,
					0 AS APositionTaking2,
					0 AS liveindicator,
					0 AS modds,
					b.custid,
					0 AS livehomescore,
					0 AS liveawayscore,
					0 AS finalhomescore,
					0 AS finalawayscore,
					0 AS leagueid,
					b.productID AS Sporttype,
					b.ip,
					0 AS MatchId,
					CONVERT(BIT, 0) AS IsNeutral,
					(b.winlost - b.actual_stake) AS winlost,
					b.playercomm AS Commission,
					(b.scomm - b.acomm) AS scomm,
					(b.acomm - b.comm) AS acomm,
					(b.comm - b.playercomm) AS comm,
					b.awinlost,
					b.mwinlost,
					b.swinlost,
					'' AS showtime,
					b.winlostdate,
					b.TranId3rd AS BetCheck,
					b.transdesc,
					CASE
						WHEN pj.ProductId IS NOT NULL AND b.statusID IN (111, 112, 113) THEN ISNULL(b.BetStake, 0)
						ELSE 0
					END AS OddsSpread,
					0 AS OriginalBetType,
					CASE
						WHEN pj.ProductId IS NOT NULL THEN ISNULL(b.RefNo2, -1)
						ELSE -1
					END AS BetdaqId,
					b.ExtraInfo,
					CASE
						WHEN pj.ProductId IS NOT NULL THEN ISNULL(b.JackpotInfo, '')
						ELSE ''
					END AS JackpotInfo,
					0 AS WalletType,
					0 AS RefCode,
					b.currency,
					b.SiteId,
					0 AS LeagueGroupID,
					b.DeviceType
				FROM dbo.bettransRnG AS b WITH (NOLOCK)
					INNER JOIN @SportBettype AS s ON s.Bettype = b.gameID
					LEFT JOIN @ProductJackpot AS pj ON s.ProductId = pj.ProductId
				WHERE b.transid = @TransId
					AND (s.ProductId IN (22, 32, 34, 36, 42, 50, 55, 56, 60, 61, 62, 66, 67, 68, 72, 73, 75, 78, 79, 86)
						OR (s.ProductId = 6 AND s.SubProduct <> '')
						OR RefTable = 1)
			END
		END

		-- bettransRnG14
		ELSE IF @WinLostDate BETWEEN @BalanceUpDay AND @MoveBetsDay
		BEGIN
			-- RNG Casino Single Wallet, Macau Games, Pragmatic Casino, Card Club, Spadegaming, Saba.club, RNG War, PG Soft, Joker, MaxGame, Habanero, CG, VGaming
			-- AdvantPlay, AdvantPlay Mini, SEAL Entertainment, MG RNG Casino, Jili, Live22, UU Slots, Saba xD
			IF EXISTS (	SELECT TOP(1) 1 FROM @SportBettype
						WHERE Bettype = @BetType
							AND (ProductID IN (22, 32, 34, 36, 42, 50, 55, 56, 60, 61, 62, 66, 67, 68, 72, 73, 75, 78, 79, 86)
								OR (ProductID = 6 AND SubProduct <> '')
								OR RefTable = 1))
			BEGIN
				INSERT INTO @Data (
					BetType, TransId, BetId, RefNo, MatchCode, Race, EventDate, VirtualRate, IsShowOTExRate,
					SDiscount, ADiscount, Discount, HomeId, AwayId, SettleTime, Hdp1, Hdp2, Odds, FinalOdds,
					FinalOdds2, OddsType, Status, SettlementStatus, ComStatus, Stake, Actual_Stake, TransDate,
					BetTeam, SPositionTaking, MPositionTaking, APositionTaking, SPositionTaking2, MPositionTaking2,
					APositionTaking2, LiveIndicator, Modds, CustId, LiveHomeScore, LiveAwayScore, FinalHomeScore,
					FinalAwayScore, LeagueId, SportType, Ip, MatchId, IsNeutral, WinLost, Commission, SComm,
					AComm, Comm, AWinLost, MWinLost, SWinLost, ShowTime, WinLostDate, BetCheck, TransDesc,
					OddsSpread, OriginalBetType, BetdaqId, ExtraInfo, JackpotInfo, WalletType, RefCode,
					CurrencyId, SiteId, LeagueGroupId, DeviceType
				)
				SELECT
					b.gameID AS BetType,
					b.transid,
					0 AS BetId,
					b.refno,
					CASE
						WHEN s.productID IN (42) THEN ISNULL(b.SiteID, '')
						ELSE b.Additional
					END AS MatchCode,
					'' AS Race,
					CASE
						WHEN s.productID IN (60) THEN b.Transdate3rd
						ELSE ''
					END AS EventDate,
					0 AS virtualrate,
					0 AS isShowOTExRate,
					b.sdiscount,
					CASE
						WHEN b.mrecommend = -4 THEN 0
						ELSE b.adiscount
					END,
					CASE
						WHEN b.recommend IN (-3, -4) THEN 0
						ELSE b.discount
					END,
					0 AS homeid,
					0 AS awayid,
					'' AS settleTime,
					0 AS hdp1,
					0 AS hdp2,
					CASE
						WHEN pj.ProductId IS NOT NULL  AND b.statusID IN (111, 112, 113) THEN ISNULL(b.ContributionRate, 0)
						ELSE b.odds
					END AS Odds,
					0 AS finalodds,
					0 AS finalodds2,
					0 AS OddsType,
					b.status,
					0 AS SettlementStatus,
					'' AS comstatus,
					b.stake,
					b.actual_stake,
					b.transdate,
					b.GameId3rd AS betteam,
					b.spositiontaking,
					b.mpositiontaking,
					b.apositiontaking,
					0 AS SPositionTaking2,
					0 AS MPositionTaking2,
					0 AS APositionTaking2,
					0 AS liveindicator,
					0 AS modds,
					b.custid,
					0 AS livehomescore,
					0 AS liveawayscore,
					0 AS finalhomescore,
					0 AS finalawayscore,
					0 AS leagueid,
					b.productID AS Sporttype,
					b.ip,
					0 AS MatchId,
					CONVERT(BIT, 0) AS IsNeutral,
					(b.winlost - b.actual_stake) AS winlost,
					b.playercomm AS Commission,
					(b.scomm - b.acomm) AS scomm,
					(b.acomm - b.comm) AS acomm,
					(b.comm - b.playercomm) AS comm,
					b.awinlost,
					b.mwinlost,
					b.swinlost,
					'' AS showtime,
					b.winlostdate,
					b.TranId3rd AS BetCheck,
					b.transdesc,
					CASE
						WHEN pj.ProductId IS NOT NULL  AND b.statusID IN (111, 112, 113) THEN ISNULL(b.BetStake, 0)
						ELSE 0
					END AS OddsSpread,
					0 AS OriginalBetType,
					CASE
						WHEN pj.ProductId IS NOT NULL  THEN ISNULL(b.RefNo2, -1)
						ELSE -1
					END AS BetdaqId,
					b.ExtraInfo,
					CASE
						WHEN pj.ProductId IS NOT NULL THEN ISNULL(b.JackpotInfo, '')
						ELSE ''
					END AS JackpotInfo,
					0 AS WalletType,
					0 AS RefCode,
					b.currency,
					b.SiteId,
					0 AS LeagueGroupID,
					b.DeviceType
				FROM dbo.bettransRnG14 AS b WITH (NOLOCK)
					INNER JOIN @SportBettype AS s ON s.Bettype = b.gameID
					LEFT JOIN @ProductJackpot AS pj ON s.ProductId = pj.ProductId
				WHERE b.transid = @TransId
					AND (s.ProductId IN (22, 32, 34, 36, 42, 50, 55, 56, 60, 61, 62, 66, 67, 68, 72, 73, 75, 78, 79, 86)
						OR (s.ProductId = 6 AND s.SubProduct <> '')
						OR RefTable = 1)
			END
		END
	END

	-- BettransLC tables
	SET @WinLostDate = NULL
	SET @CustId = NULL

	IF @ExcludeBettrans = 0
	BEGIN
		-- bettransLC
		SELECT TOP(1)
			@TransId = b.transid,
			@BetType = b.gameID,
			@WinLostDate = b.winlostdate,
			@CustId = b.custid
		FROM dbo.bettransLC AS b WITH (NOLOCK)
			INNER JOIN @SportBettype AS sp ON b.gameID = sp.bettype
		WHERE b.transid = @RefNo
	END

	-- bettransLC14
	IF @WinLostDate IS NULL
	BEGIN
		SELECT TOP(1)
			@TransId = b.transid,
			@BetType = b.gameID,
			@WinLostDate = b.winlostdate,
			@CustId = b.custid
		FROM dbo.bettransLC14 AS b WITH (NOLOCK)
			INNER JOIN @SportBettype AS sp ON b.gameID = sp.bettype
		WHERE b.transid = @RefNo
	END

	IF @WinLostDate IS NOT NULL
		AND NOT EXISTS ( SELECT 1
						FROM dbo.customer AS c WITH (NOLOCK)
							INNER JOIN dbo.customer AS a WITH (NOLOCK) ON c.recommend = a.custid
							WHERE c.custid = @CustId
								AND a.site IN (SELECT Site FROM @DeniedSite))
		AND NOT EXISTS ( SELECT 1
						FROM dbo.customer AS c WITH (NOLOCK)
						WHERE c.custid = @CustId
							AND c.currency IN (SELECT ExchangeId FROM @DeniedCurrency))
	BEGIN
		-- bettransLC
		IF @WinLostDate > @MoveBetsDay
		BEGIN
			-- AG Casino, AllBet, Sexy Gaming, IBCBet Live Casino, ION, WM, Big Gaming, FGG, YeeBet, WE
			IF EXISTS ( SELECT TOP(1) 1 FROM @SportBettype WHERE (ProductID IN (11, 21, 45, 46, 51, 52, 57, 65, 70, 76, 80) OR RefTable = 2) AND Bettype = @BetType )
			BEGIN
				INSERT INTO @Data (
					BetType, TransId, BetId, RefNo, MatchCode, Race, EventDate, VirtualRate, IsShowOTExRate,
					SDiscount, ADiscount, Discount, HomeId, AwayId, SettleTime, Hdp1, Hdp2, Odds, FinalOdds,
					FinalOdds2, OddsType, Status, SettlementStatus, ComStatus, Stake, Actual_Stake, TransDate,
					BetTeam, SPositionTaking, MPositionTaking, APositionTaking, SPositionTaking2, MPositionTaking2,
					APositionTaking2, LiveIndicator, Modds, CustId, LiveHomeScore, LiveAwayScore, FinalHomeScore,
					FinalAwayScore, LeagueId, SportType, Ip, MatchId, IsNeutral, WinLost, Commission, SComm,
					AComm, Comm, AWinLost, MWinLost, SWinLost, ShowTime, WinLostDate, BetCheck, TransDesc,
					OddsSpread, OriginalBetType, BetdaqId, ExtraInfo, JackpotInfo, WalletType, RefCode,
					CurrencyId, SiteId, LeagueGroupId, DeviceType
				)
				SELECT
					b.gameID AS BetType,
					b.transid,
					0 AS BetId,
					b.refno,
					CASE
						WHEN s.ProductID = 11 THEN ''
						ELSE b.GameId3rd
					END AS matchcode,
					'' AS Race,
					CASE
						WHEN s.ProductID IN (70) THEN b.TransDate3rd
						ELSE '' 
					END AS eventdate,
					0 AS virtualrate,
					0 AS isShowOTExRate,
					b.sdiscount,
					CASE
						WHEN b.mrecommend = -4 THEN 0
						ELSE b.adiscount
					END,
					CASE
						WHEN b.recommend IN (-3, -4) THEN 0
						ELSE b.discount
					END,
					0 AS homeid,
					0 AS awayid,
					'' AS settleTime,
					0 AS hdp1,
					0 AS hdp2,
					CASE
						WHEN s.ProductID IN (21, 45, 46, 51, 52, 57, 76, 80, 96) THEN b.odds
						WHEN pj.ProductId IS NOT NULL  AND b.statusID IN (111, 112, 113) THEN ISNULL(b.ContributionRate, 0)
						ELSE 0
					END AS odds,
					0 AS finalodds,
					0 AS finalodds2,
					0 AS OddsType,
					b.status,
					0 AS SettlementStatus,
					'' AS comstatus,
					b.stake,
					b.actual_stake,
					b.transdate,
					'' AS betteam,
					b.spositiontaking,
					b.mpositiontaking,
					b.apositiontaking,
					0 AS SPositionTaking2,
					0 AS MPositionTaking2,
					0 AS APositionTaking2,
					0 AS liveindicator,
					0 AS modds,
					b.custid,
					0 AS livehomescore,
					0 AS liveawayscore,
					0 AS finalhomescore,
					0 AS finalawayscore,
					0 AS leagueid,
					b.productID AS Sporttype,
					b.ip,
					0 AS MatchId,
					CONVERT(BIT, 0) AS IsNeutral,
					(b.winlost - b.actual_stake) AS winlost,
					b.playercomm AS Commission,
					(b.scomm - b.acomm) AS scomm,
					(b.acomm - b.comm) AS acomm,
					(b.comm - b.playercomm) AS comm,
					b.awinlost,
					b.mwinlost,
					b.swinlost,
					'' AS showtime,
					b.winlostdate,
					b.TranId3rd AS BetCheck,
					b.transdesc,
					CASE
						WHEN pj.ProductId IS NOT NULL  AND b.statusID IN (111, 112, 113) THEN ISNULL(b.BetStake, 0)
						ELSE 0
					END AS OddsSpread,
					0 AS OriginalBetType,
					CASE
						WHEN pj.ProductId IS NOT NULL  THEN ISNULL(b.RefNo2, -1)
						ELSE -1
					END AS BetdaqId,
					b.ExtraInfo,
					CASE
						WHEN pj.ProductId IS NOT NULL THEN ISNULL(b.JackpotInfo, '')
						ELSE ''
					END AS JackpotInfo,
					0 AS WalletType,
					0 AS RefCode,
					b.currency,
					b.SiteId,
					0 AS LeagueGroupID,
					b.DeviceType
				FROM dbo.bettransLC AS b WITH (NOLOCK)
					INNER JOIN @SportBettype AS s ON s.Bettype = b.gameID
					LEFT JOIN @ProductJackpot AS pj ON s.ProductId = pj.ProductId
				WHERE b.transid = @TransId
					AND (s.ProductID IN (11, 21, 45, 46, 51, 52, 57, 65, 70, 76, 80) OR s.RefTable = 2)
			END
		END

		-- bettransLC14
		ELSE IF @WinLostDate BETWEEN @BalanceUpDay AND @MoveBetsDay
		BEGIN
			-- AG Casino, AllBet, Sexy Gaming, IBCBet Live Casino, ION, WM, Big Gaming, PP Live Casino, FGG, YeeBet, WE
			IF EXISTS ( SELECT TOP(1) 1 FROM @SportBettype WHERE (ProductID IN (11, 21, 45, 46, 51, 52, 57, 65, 70, 76, 80) OR RefTable = 2) AND Bettype = @BetType )
			BEGIN
				INSERT INTO @Data (
					BetType, TransId, BetId, RefNo, MatchCode, Race, EventDate, VirtualRate, IsShowOTExRate,
					SDiscount, ADiscount, Discount, HomeId, AwayId, SettleTime, Hdp1, Hdp2, Odds, FinalOdds,
					FinalOdds2, OddsType, Status, SettlementStatus, ComStatus, Stake, Actual_Stake, TransDate,
					BetTeam, SPositionTaking, MPositionTaking, APositionTaking, SPositionTaking2, MPositionTaking2,
					APositionTaking2, LiveIndicator, Modds, CustId, LiveHomeScore, LiveAwayScore, FinalHomeScore,
					FinalAwayScore, LeagueId, SportType, Ip, MatchId, IsNeutral, WinLost, Commission, SComm,
					AComm, Comm, AWinLost, MWinLost, SWinLost, ShowTime, WinLostDate, BetCheck, TransDesc,
					OddsSpread, OriginalBetType, BetdaqId, ExtraInfo, JackpotInfo, WalletType, RefCode,
					CurrencyId, SiteId, LeagueGroupId, DeviceType
				)
				SELECT
					b.gameID AS BetType,
					b.transid,
					0 AS BetId,
					b.refno,
					CASE 
						WHEN s.ProductID = 11 THEN ''
						ELSE b.GameId3rd
					END AS matchcode,
					'' AS Race,
					CASE
						WHEN s.ProductID IN (70) THEN b.TransDate3rd
						ELSE '' 
					END AS eventdate,
					0 AS virtualrate,
					0 AS isShowOTExRate,
					b.sdiscount,
					CASE
						WHEN b.mrecommend = -4 THEN 0
						ELSE b.adiscount
					END,
					CASE
						WHEN b.recommend IN (-3, -4) THEN 0
						ELSE b.discount
					END,
					0 AS homeid,
					0 AS awayid,
					'' AS settleTime,
					0 AS hdp1,
					0 AS hdp2,
					CASE
						WHEN s.ProductID IN (21, 45, 46, 51, 52, 57, 76, 80, 96) THEN b.odds
						WHEN pj.ProductId IS NOT NULL  AND b.statusID IN (111, 112, 113) THEN ISNULL(b.ContributionRate, 0)
						ELSE 0
					END AS odds,
					0 AS finalodds,
					0 AS finalodds2,
					0 AS OddsType,
					b.status,
					0 AS SettlementStatus,
					'' AS comstatus,
					b.stake,
					b.actual_stake,
					b.transdate,
					'' AS betteam,
					b.spositiontaking,
					b.mpositiontaking,
					b.apositiontaking,
					0 AS SPositionTaking2,
					0 AS MPositionTaking2,
					0 AS APositionTaking2,
					0 AS liveindicator,
					0 AS modds,
					b.custid,
					0 AS livehomescore,
					0 AS liveawayscore,
					0 AS finalhomescore,
					0 AS finalawayscore,
					0 AS leagueid,
					b.productID AS Sporttype,
					b.ip,
					0 AS MatchId,
					CONVERT(BIT, 0) AS IsNeutral,
					(b.winlost - b.actual_stake) AS winlost,
					b.playercomm AS Commission,
					(b.scomm - b.acomm) AS scomm,
					(b.acomm - b.comm) AS acomm,
					(b.comm - b.playercomm) AS comm,
					b.awinlost,
					b.mwinlost,
					b.swinlost,
					'' AS showtime,
					b.winlostdate,
					b.TranId3rd AS BetCheck,
					b.transdesc,
					CASE
						WHEN pj.ProductId IS NOT NULL  AND b.statusID IN (111, 112, 113) THEN ISNULL(b.BetStake, 0)
						ELSE 0
					END AS OddsSpread,
					0 AS OriginalBetType,
					CASE
						WHEN pj.ProductId IS NOT NULL  THEN ISNULL(b.RefNo2, -1)
						ELSE -1
					END AS BetdaqId,
					b.ExtraInfo,
					CASE
						WHEN pj.ProductId IS NOT NULL THEN ISNULL(b.JackpotInfo, '')
						ELSE ''
					END AS JackpotInfo,
					0 AS WalletType,
					0 AS RefCode,
					b.currency,
					b.SiteId,
					0 AS LeagueGroupID,
					b.DeviceType
				FROM dbo.bettransLC14 AS b WITH (NOLOCK)
					INNER JOIN @SportBettype AS s ON s.Bettype = b.gameID
					LEFT JOIN @ProductJackpot AS pj ON s.ProductId = pj.ProductId
				WHERE b.transid = @TransId
					AND (s.ProductID IN (11, 21, 45, 46, 51, 52, 57, 65, 70, 76, 80) OR s.RefTable = 2)
			END
		END
	END

	-- Get AllBet, Sexy Gaming, IBCBet Live Casino, WM, Big Gaming, PP Live Casino, FGG, YeeBet, WE related tickets (same game)
	IF @WinLostDate IS NOT NULL
		AND EXISTS (SELECT 1
					FROM @Data AS b
						INNER JOIN @SportBettype AS s ON s.Bettype = b.bettype
					WHERE (s.ProductID IN (21, 45, 46, 51, 57, 65, 70, 76, 80) OR s.RefTable = 2) AND b.MatchCode <> '')
	BEGIN
		IF @WinLostDate > @MoveBetsDay
		BEGIN
			INSERT INTO @Data (
					BetType, TransId, BetId, RefNo, MatchCode, Race, EventDate, VirtualRate, IsShowOTExRate,
					SDiscount, ADiscount, Discount, HomeId, AwayId, SettleTime, Hdp1, Hdp2, Odds, FinalOdds,
					FinalOdds2, OddsType, Status, SettlementStatus, ComStatus, Stake, Actual_Stake, TransDate,
					BetTeam, SPositionTaking, MPositionTaking, APositionTaking, SPositionTaking2, MPositionTaking2,
					APositionTaking2, LiveIndicator, Modds, CustId, LiveHomeScore, LiveAwayScore, FinalHomeScore,
					FinalAwayScore, LeagueId, SportType, Ip, MatchId, IsNeutral, WinLost, Commission, SComm,
					AComm, Comm, AWinLost, MWinLost, SWinLost, ShowTime, WinLostDate, BetCheck, TransDesc,
					OddsSpread, OriginalBetType, BetdaqId, ExtraInfo, JackpotInfo, WalletType, RefCode,
					CurrencyId, SiteId, LeagueGroupId, DeviceType
				)
			SELECT
				b.gameID AS BetType,
				b.transid,
				0 AS BetId,
				b.refno,
				CASE
					WHEN s.ProductID = 11 THEN ''
					ELSE b.GameId3rd
				END AS matchcode,
				'' AS Race,
				CASE
					WHEN s.ProductID IN (70, 90) THEN b.TransDate3rd
					ELSE '' 
				END AS eventdate,
				0 AS virtualrate,
				0 AS isShowOTExRate,
				b.sdiscount,
				CASE
					WHEN b.mrecommend = -4 THEN 0
					ELSE b.adiscount
				END,
				CASE
					WHEN b.recommend IN (-3, -4) THEN 0
					ELSE b.discount
				END,
				0 AS homeid,
				0 AS awayid,
				'' AS settleTime,
				0 AS hdp1,
				0 AS hdp2,
				CASE
					WHEN s.ProductID IN (21, 45, 46, 51, 57, 76, 80, 96) THEN b.odds
					WHEN pj.ProductId IS NOT NULL  AND b.statusID IN (111, 112, 113) THEN ISNULL(b.ContributionRate, 0)
					ELSE 0
				END AS odds,
				0 AS finalodds,
				0 AS finalodds2,
				0 AS OddsType,
				b.status,
				0 AS SettlementStatus,
				'' AS comstatus,
				b.stake,
				b.actual_stake,
				b.transdate,
				'' AS betteam,
				b.spositiontaking,
				b.mpositiontaking,
				b.apositiontaking,
				0 AS SPositionTaking2,
				0 AS MPositionTaking2,
				0 AS APositionTaking2,
				0 AS liveindicator,
				0 AS modds,
				b.custid,
				0 AS livehomescore,
				0 AS liveawayscore,
				0 AS finalhomescore,
				0 AS finalawayscore,
				0 AS leagueid,
				b.productID AS Sporttype,
				b.ip,
				0 AS MatchId,
				CONVERT(BIT, 0) AS IsNeutral,
				(b.winlost - b.actual_stake) AS winlost,
				b.playercomm AS Commission,
				(b.scomm - b.acomm) AS scomm,
				(b.acomm - b.comm) AS acomm,
				(b.comm - b.playercomm) AS comm,
				b.awinlost,
				b.mwinlost,
				b.swinlost,
				'' AS showtime,
				b.winlostdate,
				b.TranId3rd AS BetCheck,
				b.transdesc,
				CASE
						WHEN pj.ProductId IS NOT NULL  AND b.statusID IN (111, 112, 113) THEN ISNULL(b.BetStake, 0)
						ELSE 0
					END AS OddsSpread,
				0 AS OriginalBetType,
				CASE
						WHEN pj.ProductId IS NOT NULL  THEN ISNULL(b.RefNo2, -1)
						ELSE -1
					END AS BetdaqId,
				b.ExtraInfo,
				CASE
						WHEN pj.ProductId IS NOT NULL THEN ISNULL(b.JackpotInfo, '')
						ELSE ''
					END AS JackpotInfo,
				0 AS WalletType,
				0 AS RefCode,
				b.currency,
				b.SiteId,
				0 AS LeagueGroupID,
				b.DeviceType
			FROM dbo.bettransLC AS b WITH (NOLOCK)
				INNER JOIN @Data AS b1 ON b.custid = b1.CustId AND b.gameID = b1.BetType AND b.GameId3rd = b1.MatchCode
				INNER JOIN @SportBettype AS s ON s.Bettype = b1.bettype
				LEFT JOIN @ProductJackpot AS pj ON s.ProductId = pj.ProductId
			WHERE (s.ProductID IN (21, 45, 46, 51, 57, 65, 70, 76, 80) OR s.RefTable = 2)
				AND b1.MatchCode <> ''
				AND b.transid <> @TransId
		END

		-- bettransLC14
		ELSE IF @WinLostDate BETWEEN @BalanceUpDay AND @MoveBetsDay
		BEGIN
			INSERT INTO @Data (
					BetType, TransId, BetId, RefNo, MatchCode, Race, EventDate, VirtualRate, IsShowOTExRate,
					SDiscount, ADiscount, Discount, HomeId, AwayId, SettleTime, Hdp1, Hdp2, Odds, FinalOdds,
					FinalOdds2, OddsType, Status, SettlementStatus, ComStatus, Stake, Actual_Stake, TransDate,
					BetTeam, SPositionTaking, MPositionTaking, APositionTaking, SPositionTaking2, MPositionTaking2,
					APositionTaking2, LiveIndicator, Modds, CustId, LiveHomeScore, LiveAwayScore, FinalHomeScore,
					FinalAwayScore, LeagueId, SportType, Ip, MatchId, IsNeutral, WinLost, Commission, SComm,
					AComm, Comm, AWinLost, MWinLost, SWinLost, ShowTime, WinLostDate, BetCheck, TransDesc,
					OddsSpread, OriginalBetType, BetdaqId, ExtraInfo, JackpotInfo, WalletType, RefCode,
					CurrencyId, SiteId, LeagueGroupId, DeviceType
				)
			SELECT
				b.gameID AS BetType,
				b.transid,
				0 AS BetId,
				b.refno,
				CASE
					WHEN s.ProductID = 11 THEN ''
					ELSE b.GameId3rd
				END AS matchcode,
				'' AS Race,
				CASE
					WHEN s.ProductID IN (70, 90) THEN b.TransDate3rd
					ELSE '' 
				END AS eventdate,
				0 AS virtualrate,
				0 AS isShowOTExRate,
				b.sdiscount,
				CASE
					WHEN b.mrecommend = -4 THEN 0
					ELSE b.adiscount
				END,
				CASE
					WHEN b.recommend IN (-3, -4) THEN 0
					ELSE b.discount
				END,
				0 AS homeid,
				0 AS awayid,
				'' AS settleTime,
				0 AS hdp1,
				0 AS hdp2,
				CASE
					WHEN s.ProductID IN (21, 45, 46, 51, 57, 76, 80, 96) THEN b.odds
					WHEN pj.ProductId IS NOT NULL  AND b.statusID IN (111, 112, 113) THEN ISNULL(b.ContributionRate, 0)
					ELSE 0
				END AS odds,
				0 AS finalodds,
				0 AS finalodds2,
				0 AS OddsType,
				b.status,
				0 AS SettlementStatus,
				'' AS comstatus,
				b.stake,
				b.actual_stake,
				b.transdate,
				'' AS betteam,
				b.spositiontaking,
				b.mpositiontaking,
				b.apositiontaking,
				0 AS SPositionTaking2,
				0 AS MPositionTaking2,
				0 AS APositionTaking2,
				0 AS liveindicator,
				0 AS modds,
				b.custid,
				0 AS livehomescore,
				0 AS liveawayscore,
				0 AS finalhomescore,
				0 AS finalawayscore,
				0 AS leagueid,
				b.productID AS Sporttype,
				b.ip,
				0 AS MatchId,
				CONVERT(BIT, 0) AS IsNeutral,
				(b.winlost - b.actual_stake) AS winlost,
				b.playercomm AS Commission,
				(b.scomm - b.acomm) AS scomm,
				(b.acomm - b.comm) AS acomm,
				(b.comm - b.playercomm) AS comm,
				b.awinlost,
				b.mwinlost,
				b.swinlost,
				'' AS showtime,
				b.winlostdate,
				b.TranId3rd AS BetCheck,
				b.transdesc,
				CASE
						WHEN pj.ProductId IS NOT NULL  AND b.statusID IN (111, 112, 113) THEN ISNULL(b.BetStake, 0)
						ELSE 0
					END AS OddsSpread,
				0 AS OriginalBetType,
				CASE
						WHEN pj.ProductId IS NOT NULL  THEN ISNULL(b.RefNo2, -1)
						ELSE -1
					END AS BetdaqId,
				b.ExtraInfo,
				CASE
						WHEN pj.ProductId IS NOT NULL THEN ISNULL(b.JackpotInfo, '')
						ELSE ''
					END AS JackpotInfo,
				0 AS WalletType,
				0 AS RefCode,
				b.currency,
				b.SiteId,
				0 AS LeagueGroupID,
				b.DeviceType
			FROM dbo.bettransLC14 AS b WITH (NOLOCK)
				INNER JOIN @Data AS b1 ON b.custid = b1.CustId AND b.gameID = b1.BetType AND b.GameId3rd = b1.MatchCode
				INNER JOIN @SportBettype AS s ON s.Bettype = b1.bettype
				LEFT JOIN @ProductJackpot AS pj ON s.ProductId = pj.ProductId
			WHERE (s.ProductID IN (21, 45, 46, 51, 57, 65, 70, 76, 80) OR s.RefTable = 2)
				AND b1.MatchCode <> ''
				AND b.transid <> @TransId
		END
	END

	-- Bettransg tables
	SET @WinLostDate = NULL
	SET @CustId = NULL

	IF @ExcludeBettrans = 0
	BEGIN
		-- bettransg
		SELECT TOP(1)
			@TransId = b.transid,
			@BetType = b.bettype,
			@WinLostDate = b.winlostdate,
			@CustId = b.custid
		FROM dbo.bettransg AS b WITH (NOLOCK)
			INNER JOIN @SportBettype AS sp ON b.bettype = sp.bettype
		WHERE b.transid = @RefNo
	END

	-- bettransg14
	IF @WinLostDate IS NULL
	BEGIN
		SELECT TOP(1)
			@TransId = b.transid,
			@BetType = b.bettype,
			@WinLostDate = b.winlostdate,
			@CustId = b.custid
		FROM dbo.bettransg14 AS b WITH (NOLOCK)
			INNER JOIN @SportBettype AS sp ON b.bettype = sp.bettype
		WHERE b.transid = @RefNo
	END

	-- bettransg bk
	IF @WinLostDate IS NULL
	BEGIN
		SELECT TOP(1)
			@TransId = b.transid,
			@BetType = b.bettype,
			@WinLostDate = b.winlostdate,
			@CustId = b.custid
		FROM bodb_Archive.dbo.bettransg AS b WITH (NOLOCK)
			INNER JOIN @SportBettype AS sp ON b.bettype = sp.bettype
		WHERE b.transid = @RefNo
	END

	IF @WinLostDate IS NOT NULL
		AND NOT EXISTS ( SELECT 1
						FROM dbo.customer AS c WITH (NOLOCK)
							INNER JOIN dbo.customer AS a WITH (NOLOCK) ON c.recommend = a.custid
							WHERE c.custid = @CustId
								AND a.site IN (SELECT Site FROM @DeniedSite))
		AND NOT EXISTS ( SELECT 1
						FROM dbo.customer AS c WITH (NOLOCK)
						WHERE c.custid = @CustId
							AND c.currency IN (SELECT ExchangeId FROM @DeniedCurrency))
	BEGIN
		-- bettransg
		IF @WinLostDate > @MoveBetsDay
		BEGIN
			-- SA Gaming
			IF EXISTS ( SELECT TOP(1) 1 FROM @SportBettype WHERE ProductID IN (39) AND Bettype = @BetType )
			BEGIN
				INSERT INTO @Data (
					BetType, TransId, BetId, RefNo, MatchCode, Race, EventDate, VirtualRate, IsShowOTExRate,
					SDiscount, ADiscount, Discount, HomeId, AwayId, SettleTime, Hdp1, Hdp2, Odds, FinalOdds,
					FinalOdds2, OddsType, Status, SettlementStatus, ComStatus, Stake, Actual_Stake, TransDate,
					BetTeam, SPositionTaking, MPositionTaking, APositionTaking, SPositionTaking2, MPositionTaking2,
					APositionTaking2, LiveIndicator, Modds, CustId, LiveHomeScore, LiveAwayScore, FinalHomeScore,
					FinalAwayScore, LeagueId, SportType, Ip, MatchId, IsNeutral, WinLost, Commission, SComm,
					AComm, Comm, AWinLost, MWinLost, SWinLost, ShowTime, WinLostDate, BetCheck, TransDesc,
					OddsSpread, OriginalBetType, BetdaqId, ExtraInfo, JackpotInfo, WalletType, RefCode,
					CurrencyId, SiteId, LeagueGroupId, DeviceType
				)
				SELECT
					b.bettype,
					b.transid,
					0 AS BetId,
					b.refno,
					ISNULL(blc.GameId3rd, '') AS matchcode,
					'' AS Race,
					'' AS eventdate,
					0 AS virtualrate,
					0 AS isShowOTExRate,
					b.sdiscount,
					CASE
						WHEN blc.mrecommend = -4 THEN 0
						ELSE b.adiscount
					END,
					CASE
						WHEN blc.recommend IN (-3, -4) THEN 0
						ELSE b.discount
					END,
					0 AS homeid,
					0 AS awayid,
					'' AS settleTime,
					0 AS hdp1,
					0 AS hdp2,
					b.odds,
					0 AS finalodds,
					0 AS finalodds2,
					0 AS OddsType,
					b.status,
					0 AS SettlementStatus,
					'' AS comstatus,
					b.stake,
					b.actual_stake,
					b.transdate,
					ISNULL(b.BetID3rd, '') AS BetTeam,
					b.spositiontaking,
					b.mpositiontaking,
					b.apositiontaking,
					0 AS SPositionTaking2,
					0 AS MPositionTaking2,
					0 AS APositionTaking2,
					0 AS liveindicator,
					0 AS modds,
					b.custid,
					0 AS livehomescore,
					0 AS liveawayscore,
					0 AS finalhomescore,
					0 AS finalawayscore,
					0 AS leagueid,
					ISNULL(blc.ProductID, 0) AS Sporttype,
					ISNULL(blc.ip, '') AS Ip,
					0 AS MatchId,
					CONVERT(BIT, 0) AS IsNeutral,
					b.winlost - b.actual_stake AS WinLost,
					b.playercomm AS Commission,
					b.scomm - b.acomm AS SComm,
					b.acomm - b.comm AS AComm,
					b.comm - b.playercomm AS Comm,
					b.awinlost,
					b.mwinlost,
					b.swinlost,
					'' AS showtime,
					b.winlostdate,
					ISNULL(b.TransDesc, '') AS BetCheck,
					ISNULL(blc.transdesc, '') AS TransDesc,
					0 AS OddsSpread,
					0 AS OriginalBetType,
					-1 AS BetdaqId,
					b.ExtraInfo,
					'' AS JackpotInfo,
					0 AS WalletType,
					0 AS RefCode,
					b2.currency,
					b.SiteId,
					0 AS LeagueGroupID,
					b.DeviceType
				FROM dbo.bettransg AS b WITH (NOLOCK)
					INNER JOIN @SportBettype AS s ON s.BetType = b.bettype
					INNER JOIN dbo.bettransLC AS blc WITH (NOLOCK) ON b.refno = blc.transid AND b.custid = blc.custid
					INNER JOIN dbo.bettrans AS b2 WITH (NOLOCK) ON b2.transid = blc.refno AND b2.custid = b.CustId
				WHERE b.transid = @TransId AND s.ProductID IN (39)
			END

			-- BBIN
			IF EXISTS ( SELECT TOP(1) 1 FROM @SportBettype WHERE ProductID IN (47) AND Bettype = @BetType )
			BEGIN
				INSERT INTO @Data (
					BetType, TransId, BetId, RefNo, MatchCode, Race, EventDate, VirtualRate, IsShowOTExRate,
					SDiscount, ADiscount, Discount, HomeId, AwayId, SettleTime, Hdp1, Hdp2, Odds, FinalOdds,
					FinalOdds2, OddsType, Status, SettlementStatus, ComStatus, Stake, Actual_Stake, TransDate,
					BetTeam, SPositionTaking, MPositionTaking, APositionTaking, SPositionTaking2, MPositionTaking2,
					APositionTaking2, LiveIndicator, Modds, CustId, LiveHomeScore, LiveAwayScore, FinalHomeScore,
					FinalAwayScore, LeagueId, SportType, Ip, MatchId, IsNeutral, WinLost, Commission, SComm,
					AComm, Comm, AWinLost, MWinLost, SWinLost, ShowTime, WinLostDate, BetCheck, TransDesc,
					OddsSpread, OriginalBetType, BetdaqId, ExtraInfo, JackpotInfo, WalletType, RefCode,
					CurrencyId, SiteId, LeagueGroupId, DeviceType
				)
				SELECT
					b.bettype,
					b.transid,
					0 AS BetId,
					b.refno,
					'' AS matchcode,
					'' AS Race,
					'' AS eventdate,
					0 AS virtualrate,
					0 AS isShowOTExRate,
					b.sdiscount,
					CASE
						WHEN b2.mrecommend = -4 THEN 0
						ELSE b.adiscount
					END,
					CASE
						WHEN b2.recommend IN (-3, -4) THEN 0
						ELSE b.discount
					END,
					0 AS homeid,
					0 AS awayid,
					'' AS settleTime,
					0 AS hdp1,
					0 AS hdp2,
					b.odds,
					0 AS finalodds,
					0 AS finalodds2,
					0 AS OddsType,
					b.status,
					0 AS SettlementStatus,
					'' AS comstatus,
					b.stake,
					b.actual_stake,
					b.transdate,
					ISNULL(b.betteam, '') AS BetTeam,
					b.spositiontaking,
					b.mpositiontaking,
					b.apositiontaking,
					0 AS SPositionTaking2,
					0 AS MPositionTaking2,
					0 AS APositionTaking2,
					0 AS liveindicator,
					0 AS modds,
					b.custid,
					0 AS livehomescore,
					0 AS liveawayscore,
					0 AS finalhomescore,
					0 AS finalawayscore,
					0 AS leagueid,
					b.matchid AS Sporttype,
					ISNULL(b2.ip, '') AS Ip,
					0 AS MatchId,
					CONVERT(BIT, 0) AS IsNeutral,
					b.winlost - b.actual_stake AS WinLost,
					b.playercomm AS Commission,
					b.scomm - b.acomm AS SComm,
					b.acomm - b.comm AS AComm,
					b.comm - b.playercomm AS Comm,
					b.awinlost,
					b.mwinlost,
					b.swinlost,
					'' AS showtime,
					b.winlostdate,
					ISNULL(b.BetID3rd, '') AS BetCheck,
					ISNULL(b.transdesc, '') AS TransDesc,
					0 AS OddsSpread,
					0 AS OriginalBetType,
					-1 AS BetdaqId,
					'' AS ExtraInfo,
					'' AS JackpotInfo,
					0 AS WalletType,
					0 AS RefCode,
					b2.currency,
					b.SiteId,
					0 AS LeagueGroupID,
					b.DeviceType
				FROM dbo.bettransg AS b WITH (NOLOCK)
					INNER JOIN @SportBettype AS s ON s.BetType = b.bettype
					INNER JOIN dbo.bettrans AS b2 WITH (NOLOCK) ON b2.transid = b.refno AND b2.custid = b.CustId
				WHERE b.transid = @TransId AND s.ProductID IN (47)
			END
		END

		-- bettransg14
		ELSE IF @WinLostDate BETWEEN @BalanceUpDay AND @MoveBetsDay
		BEGIN
			-- SA Gaming
			IF EXISTS ( SELECT TOP(1) 1 FROM @SportBettype WHERE ProductID IN (39) AND Bettype = @BetType )
			BEGIN
				INSERT INTO @Data (
					BetType, TransId, BetId, RefNo, MatchCode, Race, EventDate, VirtualRate, IsShowOTExRate,
					SDiscount, ADiscount, Discount, HomeId, AwayId, SettleTime, Hdp1, Hdp2, Odds, FinalOdds,
					FinalOdds2, OddsType, Status, SettlementStatus, ComStatus, Stake, Actual_Stake, TransDate,
					BetTeam, SPositionTaking, MPositionTaking, APositionTaking, SPositionTaking2, MPositionTaking2,
					APositionTaking2, LiveIndicator, Modds, CustId, LiveHomeScore, LiveAwayScore, FinalHomeScore,
					FinalAwayScore, LeagueId, SportType, Ip, MatchId, IsNeutral, WinLost, Commission, SComm,
					AComm, Comm, AWinLost, MWinLost, SWinLost, ShowTime, WinLostDate, BetCheck, TransDesc,
					OddsSpread, OriginalBetType, BetdaqId, ExtraInfo, JackpotInfo, WalletType, RefCode,
					CurrencyId, SiteId, LeagueGroupId, DeviceType
				)
				SELECT
					b.bettype,
					b.transid,
					0 AS BetId,
					b.refno,
					ISNULL(blc.GameId3rd, '') AS matchcode,
					'' AS Race,
					'' AS eventdate,
					0 AS virtualrate,
					0 AS isShowOTExRate,
					b.sdiscount,
					CASE
						WHEN blc.mrecommend = -4 THEN 0
						ELSE b.adiscount
					END,
					CASE
						WHEN blc.recommend IN (-3, -4) THEN 0
						ELSE b.discount
					END,
					0 AS homeid,
					0 AS awayid,
					'' AS settleTime,
					0 AS hdp1,
					0 AS hdp2,
					b.odds,
					0 AS finalodds,
					0 AS finalodds2,
					0 AS OddsType,
					b.status,
					0 AS SettlementStatus,
					'' AS comstatus,
					b.stake,
					b.actual_stake,
					b.transdate,
					ISNULL(b.BetID3rd, '') AS BetTeam,
					b.spositiontaking,
					b.mpositiontaking,
					b.apositiontaking,
					0 AS SPositionTaking2,
					0 AS MPositionTaking2,
					0 AS APositionTaking2,
					0 AS liveindicator,
					0 AS modds,
					b.custid,
					0 AS livehomescore,
					0 AS liveawayscore,
					0 AS finalhomescore,
					0 AS finalawayscore,
					0 AS leagueid,
					ISNULL(blc.ProductID, 0) AS Sporttype,
					ISNULL(blc.ip, '') AS Ip,
					0 AS MatchId,
					CONVERT(BIT, 0) AS IsNeutral,
					b.winlost - b.actual_stake AS WinLost,
					b.playercomm AS Commission,
					b.scomm - b.acomm AS SComm,
					b.acomm - b.comm AS AComm,
					b.comm - b.playercomm AS Comm,
					b.awinlost,
					b.mwinlost,
					b.swinlost,
					'' AS showtime,
					b.winlostdate,
					ISNULL(b.TransDesc, '') AS BetCheck,
					ISNULL(blc.transdesc, '') AS TransDesc,
					0 AS OddsSpread,
					0 AS OriginalBetType,
					-1 AS BetdaqId,
					b.ExtraInfo,
					'' AS JackpotInfo,
					0 AS WalletType,
					0 AS RefCode,
					b2.currency,
					b.SiteId,
					0 AS LeagueGroupID,
					b.DeviceType
				FROM dbo.bettransg14 AS b WITH (NOLOCK)
					INNER JOIN @SportBettype AS s ON s.Bettype = b.Bettype
					INNER JOIN dbo.bettransLC14 AS blc WITH (NOLOCK) ON b.refno = blc.transid AND b.custid = blc.custid
					INNER JOIN dbo.bettrans14 AS b2 WITH (NOLOCK) ON b2.transid = blc.refno AND b2.custid = b.CustId
				WHERE b.transid = @TransId AND s.ProductID IN (39)
			END

			-- BBIN
			IF EXISTS ( SELECT TOP(1) 1 FROM @SportBettype WHERE ProductID IN (47) AND Bettype = @BetType )
			BEGIN
				INSERT INTO @Data (
					BetType, TransId, BetId, RefNo, MatchCode, Race, EventDate, VirtualRate, IsShowOTExRate,
					SDiscount, ADiscount, Discount, HomeId, AwayId, SettleTime, Hdp1, Hdp2, Odds, FinalOdds,
					FinalOdds2, OddsType, Status, SettlementStatus, ComStatus, Stake, Actual_Stake, TransDate,
					BetTeam, SPositionTaking, MPositionTaking, APositionTaking, SPositionTaking2, MPositionTaking2,
					APositionTaking2, LiveIndicator, Modds, CustId, LiveHomeScore, LiveAwayScore, FinalHomeScore,
					FinalAwayScore, LeagueId, SportType, Ip, MatchId, IsNeutral, WinLost, Commission, SComm,
					AComm, Comm, AWinLost, MWinLost, SWinLost, ShowTime, WinLostDate, BetCheck, TransDesc,
					OddsSpread, OriginalBetType, BetdaqId, ExtraInfo, JackpotInfo, WalletType, RefCode,
					CurrencyId, SiteId, LeagueGroupId, DeviceType
				)
				SELECT
					b.bettype,
					b.transid,
					0 AS BetId,
					b.refno,
					'' AS matchcode,
					'' AS Race,
					'' AS eventdate,
					0 AS virtualrate,
					0 AS isShowOTExRate,
					b.sdiscount,
					CASE
						WHEN b2.mrecommend = -4 THEN 0
						ELSE b.adiscount
					END,
					CASE
						WHEN b2.recommend IN (-3, -4) THEN 0
						ELSE b.discount
					END,
					0 AS homeid,
					0 AS awayid,
					'' AS settleTime,
					0 AS hdp1,
					0 AS hdp2,
					b.odds,
					0 AS finalodds,
					0 AS finalodds2,
					0 AS OddsType,
					b.status,
					0 AS SettlementStatus,
					'' AS comstatus,
					b.stake,
					b.actual_stake,
					b.transdate,
					ISNULL(b.betteam, '') AS BetTeam,
					b.spositiontaking,
					b.mpositiontaking,
					b.apositiontaking,
					0 AS SPositionTaking2,
					0 AS MPositionTaking2,
					0 AS APositionTaking2,
					0 AS liveindicator,
					0 AS modds,
					b.custid,
					0 AS livehomescore,
					0 AS liveawayscore,
					0 AS finalhomescore,
					0 AS finalawayscore,
					0 AS leagueid,
					b.matchid AS Sporttype,
					ISNULL(b2.ip, '') AS Ip,
					0 AS MatchId,
					CONVERT(BIT, 0) AS IsNeutral,
					b.winlost - b.actual_stake AS WinLost,
					b.playercomm AS Commission,
					b.scomm - b.acomm AS SComm,
					b.acomm - b.comm AS AComm,
					b.comm - b.playercomm AS Comm,
					b.awinlost,
					b.mwinlost,
					b.swinlost,
					'' AS showtime,
					b.winlostdate,
					ISNULL(b.BetID3rd, '') AS BetCheck,
					ISNULL(b.transdesc, '') AS TransDesc,
					0 AS OddsSpread,
					0 AS OriginalBetType,
					-1 AS BetdaqId,
					'' AS ExtraInfo,
					'' AS JackpotInfo,
					0 AS WalletType,
					0 AS RefCode,
					b2.currency,
					b.SiteId,
					0 AS LeagueGroupID,
					b.DeviceType
				FROM dbo.bettransg14 AS b WITH (NOLOCK)
					INNER JOIN @SportBettype AS s ON s.Bettype = b.Bettype
					INNER JOIN dbo.bettrans14 AS b2 WITH (NOLOCK) ON b2.transid = b.refno AND b2.custid = b.CustId
				WHERE b.transid = @TransId AND s.ProductID IN (47)
			END
		END

		-- bettransg bk
		ELSE
		BEGIN
			-- SA Gaming
			IF EXISTS ( SELECT TOP(1) 1 FROM @SportBettype WHERE ProductID IN (39) AND Bettype = @BetType )
			BEGIN
				INSERT INTO @Data (
					BetType, TransId, BetId, RefNo, MatchCode, Race, EventDate, VirtualRate, IsShowOTExRate,
					SDiscount, ADiscount, Discount, HomeId, AwayId, SettleTime, Hdp1, Hdp2, Odds, FinalOdds,
					FinalOdds2, OddsType, Status, SettlementStatus, ComStatus, Stake, Actual_Stake, TransDate,
					BetTeam, SPositionTaking, MPositionTaking, APositionTaking, SPositionTaking2, MPositionTaking2,
					APositionTaking2, LiveIndicator, Modds, CustId, LiveHomeScore, LiveAwayScore, FinalHomeScore,
					FinalAwayScore, LeagueId, SportType, Ip, MatchId, IsNeutral, WinLost, Commission, SComm,
					AComm, Comm, AWinLost, MWinLost, SWinLost, ShowTime, WinLostDate, BetCheck, TransDesc,
					OddsSpread, OriginalBetType, BetdaqId, ExtraInfo, JackpotInfo, WalletType, RefCode,
					CurrencyId, SiteId, LeagueGroupId, DeviceType
				)
				SELECT
					b.bettype,
					b.transid,
					0 AS BetId,
					b.refno,
					ISNULL(blc.GameId3rd, '') AS matchcode,
					'' AS Race,
					'' AS eventdate,
					0 AS virtualrate,
					0 AS isShowOTExRate,
					b.sdiscount,
					CASE
						WHEN b2.mrecommend = -4 THEN 0
						ELSE b.adiscount
					END,
					CASE
						WHEN b2.recommend IN (-3, -4) THEN 0
						ELSE b.discount
					END,
					0 AS homeid,
					0 AS awayid,
					'' AS settleTime,
					0 AS hdp1,
					0 AS hdp2,
					b.odds,
					0 AS finalodds,
					0 AS finalodds2,
					0 AS OddsType,
					b.status,
					0 AS SettlementStatus,
					'' AS comstatus,
					b.stake,
					b.actual_stake,
					b.transdate,
					ISNULL(b.BetID3rd, '') AS BetTeam,
					b.spositiontaking,
					b.mpositiontaking,
					b.apositiontaking,
					0 AS SPositionTaking2,
					0 AS MPositionTaking2,
					0 AS APositionTaking2,
					0 AS liveindicator,
					0 AS modds,
					b.custid,
					0 AS livehomescore,
					0 AS liveawayscore,
					0 AS finalhomescore,
					0 AS finalawayscore,
					0 AS leagueid,
					ISNULL(blc.ProductID, 0) AS Sporttype,
					ISNULL(dp.ip, '') AS Ip,
					0 AS MatchId,
					CONVERT(BIT, 0) AS IsNeutral,
					b.winlost - b.actual_stake AS WinLost,
					b.playercomm AS Commission,
					b.scomm - b.acomm AS SComm,
					b.acomm - b.comm AS AComm,
					b.comm - b.playercomm AS Comm,
					b.awinlost,
					b.mwinlost,
					b.swinlost,
					'' AS showtime,
					b.winlostdate,
					ISNULL(b.TransDesc, '') AS BetCheck,
					ISNULL(blc.transdesc, '') AS TransDesc,
					0 AS OddsSpread,
					0 AS OriginalBetType,
					-1 AS BetdaqId,
					b.ExtraInfo,
					'' AS JackpotInfo,
					0 AS WalletType,
					0 AS RefCode,
					b2.currency,
					b.SiteId,
					0 AS LeagueGroupID,
					b.DeviceType
				FROM bodb_Archive.dbo.bettransg AS b WITH (NOLOCK)
					INNER JOIN @SportBettype AS s ON s.Bettype = b.Bettype
					INNER JOIN bodb_Archive.dbo.bettransLC_bk AS blc WITH (NOLOCK) ON b.refno = blc.transid AND b.custid = blc.custid
					CROSS APPLY bodb02.dbo.f_IP_Decompress(blc.Ip) AS dp
					INNER JOIN bodb_Archive.dbo.bettrans_bk AS b2 WITH (NOLOCK) ON b2.transid = blc.refno AND b2.custid = b.CustId
				WHERE b.transid = @TransId AND s.ProductID IN (39)
			END

			-- BBIN
			IF EXISTS ( SELECT TOP(1) 1 FROM @SportBettype WHERE ProductID IN (47) AND Bettype = @BetType )
			BEGIN
				INSERT INTO @Data (
					BetType, TransId, BetId, RefNo, MatchCode, Race, EventDate, VirtualRate, IsShowOTExRate,
					SDiscount, ADiscount, Discount, HomeId, AwayId, SettleTime, Hdp1, Hdp2, Odds, FinalOdds,
					FinalOdds2, OddsType, Status, SettlementStatus, ComStatus, Stake, Actual_Stake, TransDate,
					BetTeam, SPositionTaking, MPositionTaking, APositionTaking, SPositionTaking2, MPositionTaking2,
					APositionTaking2, LiveIndicator, Modds, CustId, LiveHomeScore, LiveAwayScore, FinalHomeScore,
					FinalAwayScore, LeagueId, SportType, Ip, MatchId, IsNeutral, WinLost, Commission, SComm,
					AComm, Comm, AWinLost, MWinLost, SWinLost, ShowTime, WinLostDate, BetCheck, TransDesc,
					OddsSpread, OriginalBetType, BetdaqId, ExtraInfo, JackpotInfo, WalletType, RefCode,
					CurrencyId, SiteId, LeagueGroupId, DeviceType
				)
				SELECT
					b.bettype,
					b.transid,
					0 AS BetId,
					b.refno,
					'' AS matchcode,
					'' AS Race,
					'' AS eventdate,
					0 AS virtualrate,
					0 AS isShowOTExRate,
					b.sdiscount,
					CASE
						WHEN b2.mrecommend = -4 THEN 0
						ELSE b.adiscount
					END,
					CASE
						WHEN b2.recommend IN (-3, -4) THEN 0
						ELSE b.discount
					END,
					0 AS homeid,
					0 AS awayid,
					'' AS settleTime,
					0 AS hdp1,
					0 AS hdp2,
					b.odds,
					0 AS finalodds,
					0 AS finalodds2,
					0 AS OddsType,
					b.status,
					0 AS SettlementStatus,
					'' AS comstatus,
					b.stake,
					b.actual_stake,
					b.transdate,
					ISNULL(b.betteam, '') AS BetTeam,
					b.spositiontaking,
					b.mpositiontaking,
					b.apositiontaking,
					0 AS SPositionTaking2,
					0 AS MPositionTaking2,
					0 AS APositionTaking2,
					0 AS liveindicator,
					0 AS modds,
					b.custid,
					0 AS livehomescore,
					0 AS liveawayscore,
					0 AS finalhomescore,
					0 AS finalawayscore,
					0 AS leagueid,
					b.matchid AS Sporttype,
					ISNULL(dp.ip, '') AS Ip,
					0 AS MatchId,
					CONVERT(BIT, 0) AS IsNeutral,
					b.winlost - b.actual_stake AS WinLost,
					b.playercomm AS Commission,
					b.scomm - b.acomm AS SComm,
					b.acomm - b.comm AS AComm,
					b.comm - b.playercomm AS Comm,
					b.awinlost,
					b.mwinlost,
					b.swinlost,
					'' AS showtime,
					b.winlostdate,
					ISNULL(b.BetID3rd, '') AS BetCheck,
					ISNULL(b.transdesc, '') AS TransDesc,
					0 AS OddsSpread,
					0 AS OriginalBetType,
					-1 AS BetdaqId,
					'' AS ExtraInfo,
					'' AS JackpotInfo,
					0 AS WalletType,
					0 AS RefCode,
					b2.currency,
					b.SiteId,
					0 AS LeagueGroupID,
					b.DeviceType
				FROM bodb_Archive.dbo.bettransg AS b WITH (NOLOCK)
					INNER JOIN @SportBettype AS s ON s.Bettype = b.Bettype
					INNER JOIN bodb_Archive.dbo.bettrans_bk AS b2 WITH (NOLOCK) ON b2.transid = b.refno AND b2.custid = b.CustId
					CROSS APPLY bodb02.dbo.f_IP_Decompress(b2.Ip) AS dp
				WHERE b.transid = @TransId AND s.ProductID IN (47)
			END
		END
	END

	-- Get SA Gaming, BBIN related tickets (same game)
	IF @WinLostDate IS NOT NULL
		AND EXISTS (SELECT 1
					FROM @Data AS b
						INNER JOIN @SportBettype AS s ON s.Bettype = b.bettype
					WHERE (s.ProductID = 39 AND b.MatchCode <> '')
						OR (s.ProductID = 47 AND b.BetTeam <> ''))
	BEGIN
		-- bettransg
		IF @WinLostDate > @MoveBetsDay
		BEGIN
			-- SA Gaming
			INSERT INTO @Data (
					BetType, TransId, BetId, RefNo, MatchCode, Race, EventDate, VirtualRate, IsShowOTExRate,
					SDiscount, ADiscount, Discount, HomeId, AwayId, SettleTime, Hdp1, Hdp2, Odds, FinalOdds,
					FinalOdds2, OddsType, Status, SettlementStatus, ComStatus, Stake, Actual_Stake, TransDate,
					BetTeam, SPositionTaking, MPositionTaking, APositionTaking, SPositionTaking2, MPositionTaking2,
					APositionTaking2, LiveIndicator, Modds, CustId, LiveHomeScore, LiveAwayScore, FinalHomeScore,
					FinalAwayScore, LeagueId, SportType, Ip, MatchId, IsNeutral, WinLost, Commission, SComm,
					AComm, Comm, AWinLost, MWinLost, SWinLost, ShowTime, WinLostDate, BetCheck, TransDesc,
					OddsSpread, OriginalBetType, BetdaqId, ExtraInfo, JackpotInfo, WalletType, RefCode,
					CurrencyId, SiteId, LeagueGroupId, DeviceType
				)
			SELECT
				b.bettype,
				b.transid,
				0 AS BetId,
				b.refno,
				ISNULL(blc.GameId3rd, '') AS matchcode,
				'' AS Race,
				'' AS eventdate,
				0 AS virtualrate,
				0 AS isShowOTExRate,
				b.sdiscount,
				CASE
					WHEN blc.mrecommend = -4 THEN 0
					ELSE b.adiscount
				END,
				CASE
					WHEN blc.recommend IN (-3, -4) THEN 0
					ELSE b.discount
				END,
				0 AS homeid,
				0 AS awayid,
				'' AS settleTime,
				0 AS hdp1,
				0 AS hdp2,
				b.odds,
				0 AS finalodds,
				0 AS finalodds2,
				0 AS OddsType,
				b.status,
				0 AS SettlementStatus,
				'' AS comstatus,
				b.stake,
				b.actual_stake,
				b.transdate,
				ISNULL(b.BetID3rd, '') AS BetTeam,
				b.spositiontaking,
				b.mpositiontaking,
				b.apositiontaking,
				0 AS SPositionTaking2,
				0 AS MPositionTaking2,
				0 AS APositionTaking2,
				0 AS liveindicator,
				0 AS modds,
				b.custid,
				0 AS livehomescore,
				0 AS liveawayscore,
				0 AS finalhomescore,
				0 AS finalawayscore,
				0 AS leagueid,
				ISNULL(blc.ProductID, 0) AS Sporttype,
				ISNULL(blc.ip, '') AS Ip,
				0 AS MatchId,
				CONVERT(BIT, 0) AS IsNeutral,
				b.winlost - b.actual_stake AS WinLost,
				b.playercomm AS Commission,
				b.scomm - b.acomm AS SComm,
				b.acomm - b.comm AS AComm,
				b.comm - b.playercomm AS Comm,
				b.awinlost,
				b.mwinlost,
				b.swinlost,
				'' AS showtime,
				b.winlostdate,
				ISNULL(b.TransDesc, '') AS BetCheck,
				ISNULL(blc.transdesc, '') AS TransDesc,
				0 AS OddsSpread,
				0 AS OriginalBetType,
				-1 AS BetdaqId,
				b.ExtraInfo,
				'' AS JackpotInfo,
				0 AS WalletType,
				0 AS RefCode,
				b2.currency,
				b.SiteId,
				0 AS LeagueGroupID,
				b.DeviceType
			FROM dbo.bettransg AS b WITH (NOLOCK)
				INNER JOIN @Data AS b1 ON b.custid = b1.CustId AND b.bettype = b1.BetType AND b.winlostdate = b1.WinLostDate
				INNER JOIN @SportBettype AS s ON s.Bettype = b1.bettype
				INNER JOIN dbo.bettransLC AS blc WITH (NOLOCK) ON b.refno = blc.transid AND b.custid = blc.custid
				INNER JOIN dbo.bettrans AS b2 WITH (NOLOCK) ON b2.transid = blc.refno AND b2.custid = b.CustId
			WHERE b.transid <> @TransId
				AND s.productID = 39
				AND b1.MatchCode <> ''
				AND b.betteam = b1.MatchCode

			-- BBIN
			UNION ALL
			SELECT
				b.bettype,
				b.transid,
				0 AS BetId,
				b.refno,
				'' AS matchcode,
				'' AS Race,
				'' AS eventdate,
				0 AS virtualrate,
				0 AS isShowOTExRate,
				b.sdiscount,
				CASE
					WHEN b2.mrecommend = -4 THEN 0
					ELSE b.adiscount
				END,
				CASE
					WHEN b2.recommend IN (-3, -4) THEN 0
					ELSE b.discount
				END,
				0 AS homeid,
				0 AS awayid,
				'' AS settleTime,
				0 AS hdp1,
				0 AS hdp2,
				b.odds,
				0 AS finalodds,
				0 AS finalodds2,
				0 AS OddsType,
				b.status,
				0 AS SettlementStatus,
				'' AS comstatus,
				b.stake,
				b.actual_stake,
				b.transdate,
				ISNULL(b.betteam, '') AS BetTeam,
				b.spositiontaking,
				b.mpositiontaking,
				b.apositiontaking,
				0 AS SPositionTaking2,
				0 AS MPositionTaking2,
				0 AS APositionTaking2,
				0 AS liveindicator,
				0 AS modds,
				b.custid,
				0 AS livehomescore,
				0 AS liveawayscore,
				0 AS finalhomescore,
				0 AS finalawayscore,
				0 AS leagueid,
				b.matchid AS Sporttype,
				ISNULL(b2.ip, '') AS Ip,
				0 AS MatchId,
				CONVERT(BIT, 0) AS IsNeutral,
				b.winlost - b.actual_stake AS WinLost,
				b.playercomm AS Commission,
				b.scomm - b.acomm AS SComm,
				b.acomm - b.comm AS AComm,
				b.comm - b.playercomm AS Comm,
				b.awinlost,
				b.mwinlost,
				b.swinlost,
				'' AS showtime,
				b.winlostdate,
				ISNULL(b.BetID3rd, '') AS BetCheck,
				ISNULL(b.transdesc, '') AS TransDesc,
				0 AS OddsSpread,
				0 AS OriginalBetType,
				-1 AS BetdaqId,
				'' AS ExtraInfo,
				'' AS JackpotInfo,
				0 AS WalletType,
				0 AS RefCode,
				b2.currency,
				b.SiteId,
				0 AS LeagueGroupID,
				b.DeviceType
			FROM dbo.bettransg AS b WITH (NOLOCK)
				INNER JOIN @Data AS b1 ON b.custid = b1.CustId AND b.bettype = b1.BetType AND b.winlostdate = b1.WinLostDate
				INNER JOIN @SportBettype AS s ON s.Bettype = b1.bettype
				INNER JOIN dbo.bettrans AS b2 WITH (NOLOCK) ON b2.transid = b.refno AND b2.custid = b.CustId
			WHERE b.transid <> @TransId
				AND s.productID = 47
				AND b1.BetTeam <> ''
				AND b.betteam = b1.BetTeam
		END

		-- bettransg14
		ELSE IF @WinLostDate BETWEEN @BalanceUpDay AND @MoveBetsDay
		BEGIN
			-- SA Gaming
			INSERT INTO @Data (
					BetType, TransId, BetId, RefNo, MatchCode, Race, EventDate, VirtualRate, IsShowOTExRate,
					SDiscount, ADiscount, Discount, HomeId, AwayId, SettleTime, Hdp1, Hdp2, Odds, FinalOdds,
					FinalOdds2, OddsType, Status, SettlementStatus, ComStatus, Stake, Actual_Stake, TransDate,
					BetTeam, SPositionTaking, MPositionTaking, APositionTaking, SPositionTaking2, MPositionTaking2,
					APositionTaking2, LiveIndicator, Modds, CustId, LiveHomeScore, LiveAwayScore, FinalHomeScore,
					FinalAwayScore, LeagueId, SportType, Ip, MatchId, IsNeutral, WinLost, Commission, SComm,
					AComm, Comm, AWinLost, MWinLost, SWinLost, ShowTime, WinLostDate, BetCheck, TransDesc,
					OddsSpread, OriginalBetType, BetdaqId, ExtraInfo, JackpotInfo, WalletType, RefCode,
					CurrencyId, SiteId, LeagueGroupId, DeviceType
				)
			SELECT
				b.bettype,
				b.transid,
				0 AS BetId,
				b.refno,
				ISNULL(blc.GameId3rd, '') AS matchcode,
				'' AS Race,
				'' AS eventdate,
				0 AS virtualrate,
				0 AS isShowOTExRate,
				b.sdiscount,
				CASE
					WHEN blc.mrecommend = -4 THEN 0
					ELSE b.adiscount
				END,
				CASE
					WHEN blc.recommend IN (-3, -4) THEN 0
					ELSE b.discount
				END,
				0 AS homeid,
				0 AS awayid,
				'' AS settleTime,
				0 AS hdp1,
				0 AS hdp2,
				b.odds,
				0 AS finalodds,
				0 AS finalodds2,
				0 AS OddsType,
				b.status,
				0 AS SettlementStatus,
				'' AS comstatus,
				b.stake,
				b.actual_stake,
				b.transdate,
				ISNULL(b.betteam, '') AS BetTeam,
				b.spositiontaking,
				b.mpositiontaking,
				b.apositiontaking,
				0 AS SPositionTaking2,
				0 AS MPositionTaking2,
				0 AS APositionTaking2,
				0 AS liveindicator,
				0 AS modds,
				b.custid,
				0 AS livehomescore,
				0 AS liveawayscore,
				0 AS finalhomescore,
				0 AS finalawayscore,
				0 AS leagueid,
				b.matchid AS Sporttype,
				ISNULL(b2.ip, '') AS Ip,
				0 AS MatchId,
				CONVERT(BIT, 0) AS IsNeutral,
				b.winlost - b.actual_stake AS WinLost,
				b.playercomm AS Commission,
				b.scomm - b.acomm AS SComm,
				b.acomm - b.comm AS AComm,
				b.comm - b.playercomm AS Comm,
				b.awinlost,
				b.mwinlost,
				b.swinlost,
				'' AS showtime,
				b.winlostdate,
				ISNULL(b.BetID3rd, '') AS BetCheck,
				ISNULL(b.transdesc, '') AS TransDesc,
				0 AS OddsSpread,
				0 AS OriginalBetType,
				-1 AS BetdaqId,
				b.ExtraInfo,
				'' AS JackpotInfo,
				0 AS WalletType,
				0 AS RefCode,
				b2.currency,
				b.SiteId,
				0 AS LeagueGroupID,
				b.DeviceType
			FROM dbo.bettransg14 AS b WITH (NOLOCK)
				INNER JOIN @Data AS b1 ON b.custid = b1.CustId AND b.bettype = b1.BetType AND b.winlostdate = b1.WinLostDate
				INNER JOIN @SportBettype AS s ON s.Bettype = b1.bettype
				INNER JOIN dbo.bettransLC14 AS blc WITH (NOLOCK) ON b.refno = blc.transid AND b.custid = blc.custid
				INNER JOIN dbo.bettrans14 AS b2 WITH (NOLOCK) ON b2.transid = blc.refno AND b2.custid = b.CustId
			WHERE b.transid <> @TransId
				AND s.productID = 39
				AND b1.MatchCode <> ''
				AND b.betteam = b1.MatchCode

			-- BBIN
			UNION ALL
			SELECT
				b.bettype,
				b.transid,
				0 AS BetId,
				b.refno,
				'' AS matchcode,
				'' AS Race,
				'' AS eventdate,
				0 AS virtualrate,
				0 AS isShowOTExRate,
				b.sdiscount,
				CASE
					WHEN b2.mrecommend = -4 THEN 0
					ELSE b.adiscount
				END,
				CASE
					WHEN b2.recommend IN (-3, -4) THEN 0
					ELSE b.discount
				END,
				0 AS homeid,
				0 AS awayid,
				'' AS settleTime,
				0 AS hdp1,
				0 AS hdp2,
				b.odds,
				0 AS finalodds,
				0 AS finalodds2,
				0 AS OddsType,
				b.status,
				0 AS SettlementStatus,
				'' AS comstatus,
				b.stake,
				b.actual_stake,
				b.transdate,
				ISNULL(b.betteam, '') AS BetTeam,
				b.spositiontaking,
				b.mpositiontaking,
				b.apositiontaking,
				0 AS SPositionTaking2,
				0 AS MPositionTaking2,
				0 AS APositionTaking2,
				0 AS liveindicator,
				0 AS modds,
				b.custid,
				0 AS livehomescore,
				0 AS liveawayscore,
				0 AS finalhomescore,
				0 AS finalawayscore,
				0 AS leagueid,
				b.matchid AS Sporttype,
				ISNULL(b2.ip, '') AS Ip,
				0 AS MatchId,
				CONVERT(BIT, 0) AS IsNeutral,
				b.winlost - b.actual_stake AS WinLost,
				b.playercomm AS Commission,
				b.scomm - b.acomm AS SComm,
				b.acomm - b.comm AS AComm,
				b.comm - b.playercomm AS Comm,
				b.awinlost,
				b.mwinlost,
				b.swinlost,
				'' AS showtime,
				b.winlostdate,
				ISNULL(b.BetID3rd, '') AS BetCheck,
				ISNULL(b.transdesc, '') AS TransDesc,
				0 AS OddsSpread,
				0 AS OriginalBetType,
				-1 AS BetdaqId,
				'' AS ExtraInfo,
				'' AS JackpotInfo,
				0 AS WalletType,
				0 AS RefCode,
				b2.currency,
				b.SiteId,
				0 AS LeagueGroupID,
				b.DeviceType
			FROM dbo.bettransg14 AS b WITH (NOLOCK)
				INNER JOIN @Data AS b1 ON b.custid = b1.CustId AND b.bettype = b1.BetType AND b.winlostdate = b1.WinLostDate
				INNER JOIN @SportBettype AS s ON s.Bettype = b1.bettype
				INNER JOIN dbo.bettrans14 AS b2 WITH (NOLOCK) ON b2.transid = b.refno AND b2.custid = b.CustId
			WHERE b.transid <> @TransId
				AND s.productID = 47
				AND b1.BetTeam <> ''
				AND b.betteam = b1.BetTeam
		END

		-- bettransg bk
		ELSE
		BEGIN
			-- SA Gaming
			INSERT INTO @Data (
					BetType, TransId, BetId, RefNo, MatchCode, Race, EventDate, VirtualRate, IsShowOTExRate,
					SDiscount, ADiscount, Discount, HomeId, AwayId, SettleTime, Hdp1, Hdp2, Odds, FinalOdds,
					FinalOdds2, OddsType, Status, SettlementStatus, ComStatus, Stake, Actual_Stake, TransDate,
					BetTeam, SPositionTaking, MPositionTaking, APositionTaking, SPositionTaking2, MPositionTaking2,
					APositionTaking2, LiveIndicator, Modds, CustId, LiveHomeScore, LiveAwayScore, FinalHomeScore,
					FinalAwayScore, LeagueId, SportType, Ip, MatchId, IsNeutral, WinLost, Commission, SComm,
					AComm, Comm, AWinLost, MWinLost, SWinLost, ShowTime, WinLostDate, BetCheck, TransDesc,
					OddsSpread, OriginalBetType, BetdaqId, ExtraInfo, JackpotInfo, WalletType, RefCode,
					CurrencyId, SiteId, LeagueGroupId, DeviceType
				)
			SELECT
				b.bettype,
				b.transid,
				0 AS BetId,
				b.refno,
				ISNULL(blc.GameId3rd, '') AS matchcode,
				'' AS Race,
				'' AS eventdate,
				0 AS virtualrate,
				0 AS isShowOTExRate,
				b.sdiscount,
				CASE
					WHEN blc.mrecommend = -4 THEN 0
					ELSE b.adiscount
				END,
				CASE
					WHEN blc.recommend IN (-3, -4) THEN 0
					ELSE b.discount
				END,
				0 AS homeid,
				0 AS awayid,
				'' AS settleTime,
				0 AS hdp1,
				0 AS hdp2,
				b.odds,
				0 AS finalodds,
				0 AS finalodds2,
				0 AS OddsType,
				b.status,
				0 AS SettlementStatus,
				'' AS comstatus,
				b.stake,
				b.actual_stake,
				b.transdate,
				ISNULL(b.BetID3rd, '') AS BetTeam,
				b.spositiontaking,
				b.mpositiontaking,
				b.apositiontaking,
				0 AS SPositionTaking2,
				0 AS MPositionTaking2,
				0 AS APositionTaking2,
				0 AS liveindicator,
				0 AS modds,
				b.custid,
				0 AS livehomescore,
				0 AS liveawayscore,
				0 AS finalhomescore,
				0 AS finalawayscore,
				0 AS leagueid,
				ISNULL(blc.ProductID, 0) AS Sporttype,
				ISNULL(dp.ip, '') AS Ip,
				0 AS MatchId,
				CONVERT(BIT, 0) AS IsNeutral,
				b.winlost - b.actual_stake AS WinLost,
				b.playercomm AS Commission,
				b.scomm - b.acomm AS SComm,
				b.acomm - b.comm AS AComm,
				b.comm - b.playercomm AS Comm,
				b.awinlost,
				b.mwinlost,
				b.swinlost,
				'' AS showtime,
				b.winlostdate,
				ISNULL(b.TransDesc, '') AS BetCheck,
				ISNULL(blc.transdesc, '') AS TransDesc,
				0 AS OddsSpread,
				0 AS OriginalBetType,
				-1 AS BetdaqId,
				b.ExtraInfo,
				'' AS JackpotInfo,
				0 AS WalletType,
				0 AS RefCode,
				b2.currency,
				b.SiteId,
				0 AS LeagueGroupID,
				b.DeviceType
			FROM bodb_Archive.dbo.bettransg AS b WITH (NOLOCK)
				INNER JOIN @Data AS b1 ON b.custid = b1.CustId AND b.bettype = b1.bettype AND b.winlostdate = b1.WinLostDate
				INNER JOIN @SportBettype AS s ON s.Bettype = b1.bettype
				INNER JOIN bodb_Archive.dbo.bettransLC_bk AS blc WITH (NOLOCK) ON b.refno = blc.transid AND b.custid = blc.custid
				CROSS APPLY bodb02.dbo.f_IP_Decompress(blc.Ip) AS dp
				INNER JOIN bodb_Archive.dbo.bettrans_bk AS b2 WITH (NOLOCK) ON b2.transid = blc.refno AND b2.custid = b.CustId
			WHERE b.transid <> @TransId
				AND s.productID = 39
				AND b1.MatchCode <> ''
				AND b.betteam = b1.MatchCode

			-- BBIN
			UNION ALL
			SELECT
				b.bettype,
				b.transid,
				0 AS BetId,
				b.refno,
				'' AS matchcode,
				'' AS Race,
				'' AS eventdate,
				0 AS virtualrate,
				0 AS isShowOTExRate,
				b.sdiscount,
				CASE
					WHEN b2.mrecommend = -4 THEN 0
					ELSE b.adiscount
				END,
				CASE
					WHEN b2.recommend IN (-3, -4) THEN 0
					ELSE b.discount
				END,
				0 AS homeid,
				0 AS awayid,
				'' AS settleTime,
				0 AS hdp1,
				0 AS hdp2,
				b.odds,
				0 AS finalodds,
				0 AS finalodds2,
				0 AS OddsType,
				b.status,
				0 AS SettlementStatus,
				'' AS comstatus,
				b.stake,
				b.actual_stake,
				b.transdate,
				ISNULL(b.betteam, '') AS BetTeam,
				b.spositiontaking,
				b.mpositiontaking,
				b.apositiontaking,
				0 AS SPositionTaking2,
				0 AS MPositionTaking2,
				0 AS APositionTaking2,
				0 AS liveindicator,
				0 AS modds,
				b.custid,
				0 AS livehomescore,
				0 AS liveawayscore,
				0 AS finalhomescore,
				0 AS finalawayscore,
				0 AS leagueid,
				b.matchid AS Sporttype,
				ISNULL(dp.ip, '') AS Ip,
				0 AS MatchId,
				CONVERT(BIT, 0) AS IsNeutral,
				b.winlost - b.actual_stake AS WinLost,
				b.playercomm AS Commission,
				b.scomm - b.acomm AS SComm,
				b.acomm - b.comm AS AComm,
				b.comm - b.playercomm AS Comm,
				b.awinlost,
				b.mwinlost,
				b.swinlost,
				'' AS showtime,
				b.winlostdate,
				ISNULL(b.BetID3rd, '') AS BetCheck,
				ISNULL(b.transdesc, '') AS TransDesc,
				0 AS OddsSpread,
				0 AS OriginalBetType,
				-1 AS BetdaqId,
				'' AS ExtraInfo,
				'' AS JackpotInfo,
				0 AS WalletType,
				0 AS RefCode,
				b2.currency,
				b.SiteId,
				0 AS LeagueGroupID,
				b.DeviceType
			FROM bodb_Archive.dbo.bettransg AS b WITH (NOLOCK)
				INNER JOIN @Data AS b1 ON b.custid = b1.CustId AND b.bettype = b1.bettype AND b.winlostdate = b1.WinLostDate
				INNER JOIN @SportBettype AS s ON s.Bettype = b1.bettype
				INNER JOIN bodb_Archive.dbo.bettrans_bk AS b2 WITH (NOLOCK) ON b2.transid = b.refno AND b2.custid = b.CustId
				CROSS APPLY bodb02.dbo.f_IP_Decompress(b2.Ip) AS dp
			WHERE b.transid <> @TransId
				AND s.productID = 47
				AND b1.BetTeam <> ''
				AND b.betteam = b1.BetTeam
		END
	END

	SELECT 
		b.BetType,
		b.TransId,
		b.BetId,
		b.RefNo,
		b.MatchCode,
		b.Race,
		b.EventDate,
		b.VirtualRate,
		b.IsShowOTExRate,
		b.SDiscount,
		b.ADiscount,
		b.Discount,
		b.HomeId,
		b.AwayId,
		b.SettleTime,
		b.Hdp1,
		b.Hdp2,
		b.Odds,
		b.FinalOdds,
		b.FinalOdds2,
		b.OddsType,
		b.Status,
		b.SettlementStatus,
		b.ComStatus,
		b.Stake,
		b.Actual_Stake,
		b.TransDate,
		b.BetTeam,
		b.SPositionTaking,
		b.MPositionTaking,
		b.APositionTaking,
		b.SPositionTaking2,
		b.MPositionTaking2,
		b.APositionTaking2,
		b.LiveIndicator,
		b.Modds,
		b.CustId,
		b.LiveHomeScore,
		b.LiveAwayScore,
		b.FinalHomeScore,
		b.FinalAwayScore,
		b.LeagueId,
		b.SportType,
		b.Ip,
		b.MatchId,
		b.IsNeutral,
		b.WinLost,
		b.Commission,
		b.SComm,
		b.AComm,
		b.Comm,
		b.AWinLost,
		b.MWinLost,
		b.SWinLost,
		b.ShowTime,
		b.WinLostDate,
		b.BetCheck,
		b.TransDesc,
		b.OddsSpread,
		b.OriginalBetType,
		b.BetdaqId,
		b.ExtraInfo,
		b.JackpotInfo,
		b.WalletType,
		b.RefCode,
		b.CurrencyId,
		b.SiteId,
		b.LeagueGroupId,
		b.DeviceType,
		c.username,
		ex.currency,
		s.IsChinaView,
		s.SpecialPlatfrom
	FROM @Data AS b
		LEFT JOIN dbo.Customer AS c WITH (NOLOCK) ON c.CustId = b.CustId
		LEFT JOIN dbo.Exchange AS ex WITH (NOLOCK) ON c.currency = ex.exchangeid
		LEFT JOIN dbo.Site AS s WITH (NOLOCK) ON s.Site = c.Site
	ORDER BY b.TransId ASC;
END
GO
