/*<info serverAlias="DBACC-bodb02" executers="bodbAdminNet" viewers="" isFunction="0" isNested="0"></info>*/

ALTER PROCEDURE [dbo].[Acc_BetList_SelByRefNo]
	@UserId			BIGINT,
	@RefNo			BIGINT,
	@MoveBetsDay	SMALLDATETIME,
	@BalanceUpDay	SMALLDATETIME,
	@Permission		VARCHAR(20)		= '1,2,3'
AS

/*
	Created by: 20121212@Elodie
	Task: Get tickets by RefNo (display in column RefNo in bet list)
	DB: DBACC.bodb02
	Original: Acc_BetsSelBetList_ByTransID_Advance

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
*/

BEGIN
	SET NOCOUNT ON

	-- Get Sport Bettype Matrix --
	DECLARE @SportBettype TABLE (ProductID TINYINT, BetType SMALLINT, EventType TINYINT, SubProduct VARCHAR(500))

	DECLARE @IsTest BIT = 0

	SELECT @IsTest = dbo.f_CheckSPVersion(@@PROCID)

	INSERT INTO @SportBettype
	SELECT ProductID, BetType, EventType, SubProduct
	FROM dbo.f_SportBettypeMatrix_Sel (0, 0, 0, 2, '', '', @IsTest)
	WHERE BetType NOT IN (903, 904, 913, 914)
		AND ProductID NOT IN (2, 4, 7, 9, 13, 17, 19, 26, 30, 31, 33)

	DECLARE
		@TransId		BIGINT,
		@BetType		INT,
		@WinLostDate	SMALLDATETIME,
		@CustId			INT

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
		AND ( sp.productid IN (8, 12, 15, 28, 38, 40, 43, 49, 63)
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
					AND (sp.productid IN (8, 12, 15, 28, 38, 40, 43, 49, 63)
						OR sp.bettype BETWEEN 801 AND 899
						OR (sp.productid = 3 AND sp.EventType = 0) ) ) )
			AND (b.bettype NOT BETWEEN 801 AND 806
				OR b.statusID NOT IN (0, 1))
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
				AND (sp.productid IN (8, 12, 15, 28, 38, 40, 43, 49, 63)
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
		BetTeam				NVARCHAR(50),
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
		SportType			SMALLINT,
		Ip					VARCHAR(45),
		BetFrom				NVARCHAR(1),
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
		WalletType			TINYINT,
		RefCode				BIGINT
	)

	DECLARE @DeniedSite TABLE (
		SiteId			INT,
		Site			NVARCHAR(50),
		SpecialGroup	TINYINT)

	DECLARE @tmpUserid VARCHAR(50)

	SELECT @tmpUserid = CAST(@UserId AS VARCHAR(50))

	DECLARE @SearchQuery VARCHAR(1024)

	SELECT @SearchQuery = 'SELECT * 
		FROM OPENQUERY(DBPOL, 
		''SELECT siteid, site, SpecialGroup FROM NAP_UserControl.dbo.f_GetDeniedSiteByUser ( ''''' + @tmpUserid + ''''')'')'

	INSERT INTO @DeniedSite (siteid, site, SpecialGroup)
	EXECUTE(@SearchQuery)

	INSERT INTO @DeniedSite (SiteId, Site, SpecialGroup)
	SELECT
		s.siteid,
		s.site,
		s.SpecialGroup
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
	BEGIN
		-- Bettrans
		IF @WinLostDate > @MoveBetsDay
		BEGIN
			-- Sportbooks, Number Game, Virtual Sports, BetRadar Virtual Sports, Cash Out (EventType = 1)
			IF EXISTS (SELECT TOP(1) 1 FROM @SportBettype WHERE EventType = 1 AND BetType = @BetType)
			BEGIN
				INSERT INTO @Data
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
					b.adiscount,
					b.discount,
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
					b.betfrom,
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
						WHEN s.ProductID IN (5, 27) THEN CONVERT(NVARCHAR(50), m.kickofftime)
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
					CASE
						WHEN s.ProductID = 1 THEN ISNULL(b.ExtraInfo, '')
						ELSE ''
					END AS ExtraInfo,
					CASE
						WHEN s.ProductID = 1 THEN ISNULL(b.WalletType, 0)
						ELSE 0
					END AS WalletType,
					CASE
						WHEN s.ProductID = 1 THEN ISNULL(b.RefCode, 0)
						ELSE 0
					END AS RefCode
				FROM dbo.bettrans AS b WITH (NOLOCK)
					INNER JOIN @SportBettype AS s ON s.BetType = b.bettype
					INNER JOIN dbo.match AS m WITH (NOLOCK) ON b.matchid = m.matchid
				WHERE b.transid = @TransId AND s.EventType = 1

				UNION ALL -- translog metric gaming
				SELECT
					b.gameid AS BetType,
					b.translogid AS TransId,
					0 AS BetId,
					b.translogid AS RefNo,
					m.matchcode,
					'' AS Race,
					m.GlobalShowTime AS EventDate,
					0 AS virtualrate,
					0 AS isShowOTExRate,
					b.sdiscount,
					b.adiscount,
					b.discount,
					m.homeid,
					m.awayid,
					'' AS settleTime,
					0 AS hdp1,
					0 AS hdp2,
					b.odds,
					0 AS finalodds,
					0 AS finalodds2,
					CASE
						WHEN b.gameid IN (801,803,804,805,806) THEN CONVERT(TINYINT, ISNULL(b.custom1, 0))
						ELSE 0
					END AS OddsType,
					b.status,
					ISNULL(m.SettlementStatus, 0) AS SettlementStatus,
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
					m.finalhomescore,
					m.finalawayscore,
					m.leagueid,
					m.sporttype,
					b.ip,
					b.betfrom,
					b.eventID AS MatchId,
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
					b.winlostdate,
					'' AS BetCheck,
					ISNULL(b.transdesc, '') AS TransDesc,
					0 AS OddsSpread,
					0 AS OriginalBetType,
					-1 AS BetdaqId,
					'' AS ExtraInfo,
					0 AS WalletType,
					0 AS RefCode
				FROM dbo.translog AS b WITH (NOLOCK) 
					INNER JOIN @SportBettype AS s ON s.Bettype = b.gameID
					INNER JOIN dbo.match AS m WITH (NOLOCK) ON b.eventId = m.matchid
				WHERE b.translogid = @TransId
					AND b.statusID IN (0, 1)
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

			-- Mix Parlay, System Parlay, Mix Parlay (Betradar Virtual Sports)
			IF @BetType IN (9, 29, 2799)
			BEGIN
				INSERT INTO @Data
				SELECT
					b.bettype,
					CASE
						WHEN b.bettype = 29 AND ISNULL(b.betid, 0) > 0 THEN b.betid
						ELSE b.transid
					END AS TransId,
					ISNULL(b.betid, 0) AS BetId,
					b.refno,
					'' AS MatchCode,
					'' AS Race,
					'' AS EventDate,
					0 AS VirtualRate,
					0 AS IsShowOTExRate,
					b.sdiscount,
					b.adiscount,
					b.discount,
					0 AS HomeId,
					0 AS AwayId,
					'' AS SettleTime,
					b.hdp1,
					b.hdp2,
					b.odds,
					0 AS FinalOdds,
					0 AS FinalOdds2,
					0 AS OddsType,
					CASE
						WHEN b.status = 'running' THEN
							CASE
								WHEN EXISTS (SELECT 1 FROM dbo.bettransm AS bm WITH (NOLOCK)
											WHERE bm.custid = b.custid
												AND bm.refno = b.refno
												AND (bm.status = 'waiting'
													OR (bm.status = 'running' AND ISNULL(bm.SecAcceptFlag, 0) = 1 AND ISNULL(bm.checktime, CURRENT_TIMESTAMP) > CURRENT_TIMESTAMP)))
									THEN 'Waiting'
								ELSE b.status
							END
						ELSE b.status
					END AS Status,
					0 AS SettlementStatus,
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
					0 AS LiveIndicator,
					b.modds,
					b.custid,
					b.livehomescore,
					b.liveawayscore,
					0 AS FinalHomeScore,
					0 AS FinalAwayScore,
					0 AS LeagueId,
					0 AS SportType,
					b.ip,
					b.betfrom,
					0 AS MatchId,
					CONVERT(BIT, 0) AS IsNeutral,
					(b.winlost - b.actual_stake) AS WinLost,
					b.playercomm AS Commission,
					(b.scomm - b.acomm) AS SComm,
					(b.acomm - b.comm) AS AComm,
					(b.comm - b.playercomm) AS Comm,
					b.awinlost,
					b.mwinlost,
					b.swinlost,
					'' AS ShowTime,
					b.winlostdate,
					b.betcheck,
					'' AS TransDesc,
					0 AS OddsSpread,
					0 AS OriginalBetType,
					-1 AS BetdaqId,
					CASE
						WHEN b.bettype = 29 THEN ISNULL(b.ExtraInfo, '')
						ELSE ''
					END AS ExtraInfo,
					0 AS WalletType,
					0 AS RefCode
				FROM dbo.bettrans AS b WITH (NOLOCK)
				WHERE b.transid = @TransId AND b.bettype IN (9, 29, 2799)
			END

			-- Outright
			IF @BetType = 10
			BEGIN
				INSERT INTO @Data
				SELECT
					b.bettype,
					b.transid,
					ISNULL(b.betid, 0) AS BetId,
					b.refno,
					odds.matchcode,
					odds.groupmatch AS Race,
					odds.eventdate,
					0 AS VirtualRate,
					0 AS IsShowOTExRate,
					b.sdiscount,
					b.adiscount,
					b.discount,
					0 AS Homeid,
					odds.teamid AS awayid,
					'' AS SettleTime,
					b.hdp1,
					b.hdp2,
					b.odds,
					0 AS FinalOdds,
					0 AS FinalOdds2,
					b.oddstype AS OddsType,
					b.status,
					0 AS SettlementStatus,
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
					0 AS FinalHomeScore,
					0 AS FinalAwayScore,
					odds.leagueid,
					l.sporttype,
					b.ip ,
					b.betfrom,
					b.matchid,
					CONVERT(BIT,0) AS IsNeutral,
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
					b.BetCheck,
					 '' AS TransDesc,
					0 AS OddsSpread,
					0 AS OriginalBetType,
					-1 AS BetdaqId,
					'' AS ExtraInfo,
					0 AS WalletType,
					0 AS RefCode
				FROM dbo.bettrans AS b WITH (NOLOCK)
					INNER JOIN dbo.outright AS odds WITH (NOLOCK) ON b.matchid = odds.orid
					INNER JOIN dbo.league AS l WITH (NOLOCK) ON odds.leagueid = l.leagueid
				WHERE b.transid = @TransId AND b.bettype = 10
			END

			-- Keno, Gold Deluxe, NG2, Lottery, NPH Promotion, Virtual Games, Table Games, Indo 4D, BBIN, Leap Gaming Virtual Sports, Happy 5 Linked Games(Number Game), Sports Lottery
			IF EXISTS (SELECT TOP(1) 1 FROM @SportBettype
						WHERE BetType = @BetType
							AND (ProductID IN (8, 12, 23, 28, 37, 38, 40, 43, 47, 49, 63) OR (ProductID = 3 AND EventType = 0)))
			BEGIN
				INSERT INTO @Data
				SELECT
					b.bettype,
					b.transid,
					ISNULL(b.betid, 0) AS BetId,
					b.refno,
					'' AS matchcode,
					'' AS Race,
					'' AS eventdate,
					0 AS virtualrate,
					0 AS isShowOTExRate,
					b.sdiscount,
					b.adiscount,
					b.discount,
					0 AS homeid,
					0 AS awayid,
					'' AS settleTime,
					CASE
						WHEN s.ProductId = 23 THEN b.hdp1
						ELSE 0
					END AS hdp1,
					CASE
						WHEN s.ProductId = 23 THEN b.hdp2
						ELSE 0
					END AS hdp2,
					CASE
						WHEN s.ProductID IN (3, 8, 12, 23, 28, 38, 40, 43, 49, 63) THEN b.odds
						ELSE 0
					END AS odds,
					0 AS finalodds,
					0 AS finalodds2,
					0 AS OddsType,
					CASE
						WHEN s.ProductID = 40 AND b.status = 'Won' AND b.modds = 0.25 THEN 'Half Won'
						WHEN s.ProductID = 40 AND b.status = 'Lose' AND b.modds = -0.25 THEN 'Half Lose'
						ELSE b.status
					END AS status,
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
					CASE
						WHEN s.ProductId = 23 THEN b.livehomescore
						ELSE 0
					END AS livehomescore,
					0 AS LiveAwayScore,
					0,
					0,
					0 AS leagueid,
					CASE
						WHEN s.ProductID = 8 THEN 202
						WHEN s.ProductID = 12 THEN 255
						WHEN s.ProductID = 23 AND s.Bettype BETWEEN 2501 AND 2539 THEN 213
						WHEN s.ProductID = 23 AND s.Bettype BETWEEN 2541 AND 2579 THEN 214
						WHEN s.ProductID = 23 AND s.Bettype BETWEEN 2581 AND 2619 THEN 215
						WHEN s.ProductID = 23 AND s.Bettype BETWEEN 2621 AND 2659 THEN 216
						WHEN s.ProductID = 23 AND s.Bettype BETWEEN 2681 AND 2699 THEN 218
						WHEN s.ProductID = 28 THEN 220
						WHEN s.ProductID IN (3, 37, 38, 40, 43, 47, 49, 63) THEN b.matchid
						ELSE 0
					END AS SportType,
					b.ip,
					b.betfrom,
					CASE
						WHEN s.ProductID = 12 THEN b.matchid
						WHEN s.ProductID = 23 THEN b.betdaqid
						ELSE 0
					END AS MatchId,
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
					CASE
						WHEN s.ProductID IN (3, 12, 38, 63) THEN b.betcheck
						WHEN s.ProductId = 8 THEN ISNULL(b.comstatus, '')
						ELSE ''
					END AS BetCheck,
					CASE
						WHEN s.ProductID IN (3, 8, 23, 28, 38, 40, 43, 49, 63) THEN b.transdesc
						ELSE ''
					END AS TransDesc,
					0 AS OddsSpread,
					0 AS OriginalBetType,
					-1 AS BetdaqId,
					CASE
						WHEN s.ProductID IN (37, 49) THEN ISNULL(b.ExtraInfo, '')
						ELSE ''
					END AS ExtraInfo,
					0 AS WalletType,
					0 AS RefCode
				FROM dbo.bettrans AS b WITH (NOLOCK)
					INNER JOIN @SportBettype AS s ON s.Bettype = b.bettype
				WHERE b.transid = @TransId
					AND (s.ProductId IN (8, 12, 23, 28, 37, 38, 40, 43, 47, 49, 63)
							OR (s.ProductId = 3 AND s.EventType = 0))
					
			END

			-- Virtual Horse Racing
			IF EXISTS (SELECT TOP(1) 1 FROM @SportBettype WHERE ProductID = 5 AND EventType = 3 AND BetType = @BetType)
			BEGIN
				INSERT INTO @Data
				SELECT
					b.bettype,
					b.transid,
					0 AS BetId,
					b.refno,
					o.RacerNum AS MatchCode,
					b.oddsid AS Race,
					'' eventdate,
					0 AS virtualrate,
					0 AS isShowOTExRate,
					b.sdiscount,
					b.adiscount,
					b.discount,
					o.RacerID AS HomeId,
					0 AS awayID,
					'' AS SettleTime,
					b.hdp1,
					b.hdp2,
					b.odds,
					0 AS finalodds,
					0 AS finalodds2,
					b.OddsType,
					b.status,
					0 AS SettlementStatus,
					CASE WHEN b.comstatus = '1' THEN 1 ELSE 0 END AS comstatus,
					b.stake,
					b.actual_stake,
					b.transdate,
					'' AS betteam,
					CASE WHEN b.bettype = 1233 THEN bm.spositiontaking ELSE b.spositiontaking END,
					CASE WHEN b.bettype = 1233 THEN bm.mpositiontaking ELSE b.mpositiontaking END,
					CASE WHEN b.bettype = 1233 THEN bm.apositiontaking ELSE b.apositiontaking END,
					CASE WHEN b.bettype = 1233 THEN bm.spositiontaking2 ELSE 0 END,
					CASE WHEN b.bettype = 1233 THEN bm.mpositiontaking2 ELSE 0 END,
					CASE WHEN b.bettype = 1233 THEN bm.apositiontaking2 ELSE 0 END,
					0 liveindicator,
					b.modds,
					b.custid,
					b.livehomescore,
					b.liveawayscore,
					0 finalhomescore,
					0 finalawayscore,
					r.leagueid,
					r.sporttype,
					b.ip,
					b.betfrom,
					b.matchid,
					CONVERT (BIT, 0) AS IsNeutral,
					(b.winlost - b.actual_stake) AS winlost,
					b.playercomm AS Commission,
					(b.scomm - b.acomm) AS scomm,
					(b.acomm - b.comm) AS acomm,
					(b.comm - b.playercomm) AS comm,
					b.awinlost,
					b.mwinlost,
					b.swinlost,
					r.EventTime AS showtime,
					b.winlostdate,
					b.BetCheck,
					 '' AS TransDesc,
					0 AS OddsSpread,
					0 AS OriginalBetType,
					-1 AS BetdaqId,
					'' AS ExtraInfo,
					0 AS WalletType,
					0 AS RefCode
				FROM dbo.bettrans AS b WITH (NOLOCK) 
					INNER JOIN dbo.VSOutright AS o WITH (NOLOCK) ON b.oddsid = o.Orid
					INNER JOIN dbo.VSRaceInfo AS r WITH (NOLOCK) ON r.EventID = o.EventID
					INNER JOIN @SportBettype AS s ON s.BetType = b.BetType 
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
						) bm ON b.refno = bm.refno
				WHERE b.transid = @TransId
					AND s.ProductID = 5
					AND s.EventType = 3
			END

			-- Keno, Gold Deluxe, Colossus Bet, Lottery, Virtual Games, Table Games, Indo 4D, Leap Gaming Virtual Sports, Happy 5 Linked Games(Number Game), Sports Lottery (translog)
			IF EXISTS (SELECT TOP(1) 1 FROM @SportBettype
						WHERE (ProductID IN (8, 12, 15, 28, 38, 40, 43, 49, 63) OR (ProductID = 3 AND EventType = 0))
							AND Bettype = @BetType)
			BEGIN
				INSERT INTO @Data
				SELECT
					b.gameid AS BetType,
					b.translogid AS TransId,
					0 AS BetId,
					b.translogid AS RefNo,
					'' AS matchcode,
					'' AS Race,
					'' AS eventdate,
					0,
					0,
					b.sdiscount,
					b.adiscount,
					b.discount,
					0 AS homeid,
					0 AS awayid,
					'' AS settleTime,
					0 AS hdp1,
					0 AS hdp2,
					CASE
						WHEN s.ProductID IN (3, 8, 12, 28, 38, 40, 43, 49, 63) THEN b.odds
						ELSE 0
					END AS odds,
					0 AS finalodds,
					0 AS finalodds2,
					0 AS OddsType,
					b.status,
					0 AS SettlementStatus,
					0 AS comstatus,
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
					CASE
						WHEN s.ProductID = 8 THEN 202
						WHEN s.ProductID = 12 THEN 255
						WHEN s.ProductID = 15 THEN 204
						WHEN s.ProductID = 28 THEN 220
						WHEN s.ProductID IN (3, 38, 40, 43, 49, 63) THEN b.productID
						ELSE 0
					END AS SportType,
					b.ip,
					b.betfrom,
					0 AS MatchId,
					CONVERT(BIT, 0) AS IsNeutral,
					(-b.actual_stake) AS winlost,
					0 AS Commission,
					0,
					0,
					0,
					0,
					0,
					0,
					'' AS showtime,
					b.winlostdate,
					CASE
						WHEN s.ProductID IN (3, 12, 38, 63) THEN b.GameID3rd
						WHEN s.ProductID = 15 THEN b.Tranid3rd
						WHEN s.ProductId = 8 THEN ISNULL(b.custom2, '')
						WHEN s.ProductId = 49 THEN ISNULL(b.custom1, '')
						ELSE ''
					END AS BetCheck,
					CASE
						WHEN s.ProductID IN (3, 8, 28, 38, 40, 43, 49, 63) THEN ISNULL(b.transdesc, '')
						ELSE ''
					END AS TransDesc,
					0 AS OddsSpread,
					0 AS OriginalBetType,
					-1 AS BetdaqId,
					'' AS ExtraInfo,
					0 AS WalletType,
					0 AS RefCode
				FROM dbo.translog AS b WITH (NOLOCK)
					INNER JOIN @SportBettype AS s ON s.Bettype = b.gameID
				WHERE b.translogid = @TransId
					AND b.statusID IN (0, 1)
					AND (s.ProductID IN (8, 12, 15, 28, 38, 40, 43, 49, 63)
							OR (s.ProductID = 3 AND s.EventType = 0))
			END

			-- RNG Casino Single Wallet, Macau Games, Fishing World, Pragmatic Casino, Card Club, Spadegaming, Saba.club, RNG War, PG Soft, Joker, MaxGame, CG, VGaming
			-- Habanero, AdvantPlay, AdvantPlay Mini
			IF EXISTS (	SELECT TOP(1) 1 FROM @SportBettype
						WHERE Bettype = @BetType
							AND (ProductID IN (22, 24, 32, 34, 36, 42, 50, 55, 56, 60, 61, 62, 66, 67, 68)
								OR (ProductID = 6 AND SubProduct <> '')))
			BEGIN
				IF @WinLostDate >= DATEADD(DAY, DATEDIFF(DAY, 1, GETDATE()), 0)		-- yesterday and later
				BEGIN
					-- Yesterday and later running ticket
					INSERT INTO @Data
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
						AVG(brng.adiscount) AS adiscount,
						AVG(brng.discount) AS discount,
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
							WHEN s.ProductID = 24 THEN 219
							WHEN s.ProductID = 32 THEN 248
							ELSE b.matchid
						END AS Sporttype,
						b.ip,
						b.betfrom,
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
							WHEN s.ProductID IN (6, 22, 24, 32, 34, 36, 55, 56, 61, 62, 67, 68) THEN b.transdesc
							ELSE ''
						END AS TransDesc,
						0 AS OddsSpread,
						0 AS OriginalBetType,
						-1 AS BetdaqId,
						'' AS ExtraInfo,
						0 AS WalletType,
						0 AS RefCode
					FROM dbo.bettransRnG AS brng WITH (NOLOCK)
						INNER JOIN dbo.bettrans AS b WITH (NOLOCK) ON brng.RefNo = b.transid
						INNER JOIN @SportBettype AS s ON s.Bettype = b.bettype
					WHERE b.transid = @TransId
						AND (s.ProductId IN (22, 24, 32, 34, 36, 42, 50, 55, 56, 60, 61, 62, 66, 67, 68)
							OR (s.ProductId = 6 AND s.SubProduct <> ''))
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
						b.betfrom,
						b.comstatus,
						b.transdesc,
						s.ProductID

					-- Yesterday and later settled ticket
					INSERT INTO @Data
					SELECT
						b.bettype,
						b.transid,
						ISNULL(b.betid, 0) AS BetId,
						b.refno,
						'' AS matchcode,
						'' AS Race,
						'' AS eventdate,
						0 AS virtualrate,
						0 AS isShowOTExRate,
						AVG(brng.sdiscount) AS sdiscount,
						AVG(brng.adiscount) AS adiscount,
						AVG(brng.discount) AS discount,
						0 AS homeid,
						0 AS awayid,
						'' AS settleTime,
						0 AS hdp1,
						0 AS hdp2,
						CASE
							WHEN s.ProductID IN (6, 32, 42, 66)
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
							WHEN s.ProductID = 24 THEN 219
							WHEN s.ProductID = 32 THEN 248
							ELSE b.matchid
						END AS Sporttype,
						b.ip,
						b.betfrom,
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
						b.winlostdate,
						'' AS BetCheck,
						CASE
							WHEN s.ProductID IN (6, 22, 24, 32, 34, 36, 55, 56, 61, 62, 67, 68) THEN b.transdesc
							ELSE ''
						END AS TransDesc,
						CASE
							WHEN s.ProductID IN (6, 32, 42, 66) THEN ISNULL(SUM(brng.BetStake), 0)
							ELSE 0
						END AS OddsSpread,
						0 AS OriginalBetType,
						-1 AS BetdaqId,
						'' AS ExtraInfo,
						0 AS WalletType,
						0 AS RefCode
					FROM dbo.bettransRnG AS brng WITH (NOLOCK)
						INNER JOIN dbo.bettrans AS b WITH (NOLOCK) ON brng.RefNo = b.transid
						INNER JOIN @SportBettype AS s ON s.Bettype = b.bettype
					WHERE b.transid = @TransId
						AND (s.ProductId IN (22, 24, 32, 34, 36, 42, 50, 55, 56, 60, 61, 62, 66, 67, 68)
							OR (s.ProductId = 6 AND s.SubProduct <> ''))
						AND brng.statusid NOT IN (0, 1)
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
						b.betfrom,
						b.comstatus,
						b.transdesc,
						s.ProductID
				END
				ELSE
				BEGIN
					-- Before yesterday settled ticket
					INSERT INTO @Data
					SELECT
						b.bettype,
						b.transid,
						ISNULL(b.betid, 0) AS BetId,
						b.refno,
						'' AS matchcode,
						'' AS Race,
						'' AS eventdate,
						0 AS virtualrate,
						0 AS isShowOTExRate,
						b.sdiscount,
						b.adiscount,
						b.discount,
						0 AS homeid,
						0 AS awayid,
						'' AS settleTime,
						0 AS hdp1,
						0 AS hdp2,
						CASE
							WHEN s.ProductID IN (6, 32, 42, 66) THEN b.odds
							ELSE 0
						END AS Odds,
						0 AS finalodds,
						0 AS finalodds2,
						0 AS OddsType,
						b.status,
						0 AS SettlementStatus,
						CASE WHEN b.comstatus = '1' THEN 1 ELSE 0 END AS comstatus,
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
						0,
						0,
						0 AS leagueid,
						CASE
							WHEN s.ProductID = 22 THEN 212
							WHEN s.ProductID = 24 THEN 219
							WHEN s.ProductID = 32 THEN 248
							ELSE b.matchid
						END AS Sporttype,
						b.ip,
						b.betfrom,
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
						'' AS BetCheck,
						CASE
							WHEN s.ProductID IN (6, 22, 24, 32, 34, 36, 55, 56, 61, 62, 67, 68) THEN b.transdesc
							ELSE ''
						END AS TransDesc,
						CASE
							WHEN s.ProductID IN (6, 32, 42, 66) THEN ISNULL(b.oddsspread, 0)
							ELSE 0
						END AS OddsSpread,
						0 AS OriginalBetType,
						-1 AS BetdaqId,
						'' AS ExtraInfo,
						0 AS WalletType,
						0 AS RefCode
					FROM dbo.bettrans AS b WITH (NOLOCK)
						INNER JOIN @SportBettype AS s ON s.Bettype = b.bettype
					WHERE b.transid = @TransId
						AND (s.ProductId IN (22, 24, 32, 34, 36, 42, 50, 55, 56, 60, 61, 62, 66, 67, 68)
							OR (s.ProductId = 6 AND s.SubProduct <> ''))
				END
			END

			-- AG Casino, AllBet, SA Gaming, Sexy Gaming, IBCBet Live Casino, ION, WM, GDG, Big Gaming, PP Live Casino
			IF EXISTS (SELECT TOP(1) 1 FROM @SportBettype WHERE ProductID IN (11, 21, 39, 45, 46, 51, 52, 57, 59, 65) AND Bettype = @BetType)
			BEGIN
				IF @WinLostDate >= DATEADD(DAY, DATEDIFF(DAY, 1, GETDATE()), 0)		-- yesterday and later
				BEGIN
					-- Yesterday and later running ticket
					INSERT INTO @Data
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
						AVG(blc.adiscount) AS adiscount,
						AVG(blc.discount) AS discount,
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
							WHEN s.ProductID IN (39, 45, 46, 51, 52, 57, 59, 65) THEN b.matchid
						END AS Sporttype,
						b.ip,
						b.betfrom,
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
						0 AS WalletType,
						0 AS RefCode
					FROM dbo.bettransLC AS blc WITH (NOLOCK)
						INNER JOIN dbo.bettrans AS b WITH (NOLOCK) ON blc.RefNo = b.transid
						INNER JOIN @SportBettype AS s ON s.Bettype = b.bettype
					WHERE b.transid = @TransId
						AND s.ProductID IN (11, 21, 39, 45, 46, 51, 52, 57, 59, 65)
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
						b.betfrom,
						b.comstatus,
						s.ProductID,
						b.matchid

					-- Yesterday and later settled ticket
					INSERT INTO @Data
					SELECT
						b.bettype,
						b.transid,
						ISNULL(b.betid, 0) AS BetId,
						b.refno,
						'' AS matchcode,
						'' AS Race,
						'' AS eventdate,
						0 AS virtualrate,
						0 AS isShowOTExRate,
						AVG(blc.sdiscount) AS sdiscount,
						AVG(blc.adiscount) AS adiscount,
						AVG(blc.discount) AS discount,
						0 AS homeid,
						0 AS awayid,
						'' AS settleTime,
						0 AS hdp1,
						0 AS hdp2,
						0 AS odds,
						0 AS finalodds,
						0 AS finalodds2,
						0 AS OddsType,
						CASE 
							WHEN SUM(blc.winlost - blc.actual_stake) > 0 THEN 'Won'
							WHEN SUM(blc.winlost - blc.actual_stake) < 0 THEN 'Lose'
							ELSE 'Draw'
						END AS Status,
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
							WHEN s.ProductID IN (39, 45, 46, 51, 52, 57, 59, 65) THEN b.matchid
						END AS Sporttype,
						b.ip,
						b.betfrom,
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
						b.winlostdate,
						'' AS BetCheck,
						'' AS TransDesc,
						0 AS OddsSpread,
						0 AS OriginalBetType,
						-1 AS BetdaqId,
						'' AS ExtraInfo,
						0 AS WalletType,
						0 AS RefCode
					FROM dbo.bettransLC AS blc WITH (NOLOCK)
						INNER JOIN dbo.bettrans AS b WITH (NOLOCK) ON blc.RefNo = b.transid
						INNER JOIN @SportBettype AS s ON s.Bettype = b.bettype
					WHERE b.transid = @TransId
						AND s.ProductID IN (11, 21, 39, 45, 46, 51, 52, 57, 59, 65)
						AND blc.statusID <> 0
					GROUP BY
						b.transid,
						ISNULL(b.betid, 0),
						b.bettype,
						b.refno,
						b.transdate,
						b.winlostdate,
						b.custid,
						b.ip,
						b.betfrom,
						b.comstatus,
						s.ProductID,
						b.matchid
				END
				ELSE
				BEGIN
					-- Before yesterday settled ticket
					INSERT INTO @Data
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
						b.sdiscount,
						b.adiscount,
						b.discount,
						0 AS homeid,
						0 AS awayid,
						'' AS settleTime,
						0 AS hdp1,
						0 AS hdp2,
						0 AS odds,
						0 AS finalodds,
						0 AS finalodds2,
						0 AS OddsType,
						b.status,
						0 AS SettlementStatus,
						CASE WHEN b.comstatus = '1' THEN 1 ELSE 0 END AS comstatus,
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
						0,
						0,
						0 AS leagueid,
						CASE
							WHEN s.ProductID = 11 THEN 250
							WHEN s.ProductID = 21 THEN 211
							WHEN s.ProductID IN (39, 45, 46, 51, 52, 57, 59, 65) THEN b.matchid
						END AS Sporttype,
						b.ip,
						b.betfrom,
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
						'' AS BetCheck,
						'' AS TransDesc,
						0 AS OddsSpread,
						0 AS OriginalBetType,
						-1 AS BetdaqId,
						'' AS ExtraInfo,
						0 AS WalletType,
						0 AS RefCode
					FROM dbo.bettrans AS b WITH (NOLOCK)
						INNER JOIN @SportBettype AS s ON s.Bettype = b.bettype
					WHERE b.transid = @TransId
						AND s.ProductID IN (11, 21, 39, 45, 46, 51, 52, 57, 59, 65)
				END
			END

			-- Colossus Bet
			IF EXISTS (SELECT TOP(1) 1 FROM @SportBettype WHERE ProductID = 15 AND Bettype = @BetType)
			BEGIN
				INSERT INTO @Data
				SELECT
					b.bettype,
					b.transid,
					ISNULL(b.betid, 0) AS BetId,
					b.refno,
					'' AS matchcode,
					'' AS Race,
					'' AS eventdate,
					0 AS virtualrate,
					0 AS isShowOTExRate,
					b.sdiscount,
					b.adiscount,
					b.discount,
					0 AS homeid,
					0 AS awayid,
					'' AS settleTime,
					0 AS hdp1,
					0 AS hdp2,
					0 AS odds,
					0 AS finalodds,
					0 AS finalodds2,
					0 AS OddsType,
					b.status,
					0 AS SettlementStatus,
					CASE WHEN b.comstatus = '1' THEN 1 ELSE 0 END AS comstatus,
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
					0,
					0,
					0 AS leagueid,
					204 AS SportType,
					b.ip,
					b.betfrom,
					0 AS MatchId,
					CONVERT(BIT, 0) AS IsNeutral,
					(b.winlost - b.actual_stake) winlost,
					b.playercomm AS Commission,
					(b.scomm - b.acomm) AS scomm,
					(b.acomm - b.comm) AS acomm,
					(b.comm - b.playercomm) AS comm,
					b.awinlost,
					b.mwinlost,
					b.swinlost,
					'' AS showtime,
					b.winlostdate,
					ISNULL(bm.betcheck, '') AS BetCheck,
					'' AS TransDesc,
					0 AS OddsSpread,
					0 AS OriginalBetType,
					-1 AS BetdaqId,
					'' AS ExtraInfo,
					0 AS WalletType,
					0 AS RefCode
				FROM dbo.bettrans AS b WITH (NOLOCK)
					INNER JOIN @SportBettype AS s ON s.Bettype = b.bettype
					LEFT JOIN dbo.bettransm AS bm WITH (NOLOCK) ON b.refno = bm.refno AND bm.bettype = 18001
				WHERE b.transid = @TransId
					AND s.ProductID = 15
			END

			-- Bitcoin
			IF EXISTS (SELECT TOP(1) 1 FROM @SportBettype WHERE ProductID = 69 AND BetType = @BetType)
			BEGIN
				INSERT INTO @Data
				SELECT
					b.bettype,
					b.transid,
					0 AS BetId,
					b.refno,
					'' matchcode,
					'' AS Race,
					m.EndTime AS EventDate,
					0 AS VirtualRate,
					0 AS IsShowOTExRate,
					b.sdiscount,
					b.adiscount,
					b.discount,
					0 homeid,
					0 awayid,
					'' AS SettleTime,
					b.hdp1,
					0 hdp2,
					b.odds,
					0 AS finalodds,
					0 AS finalodds2,
					b.OddsType,
					b.status,
					0 AS SettlementStatus,
					0 AS comstatus,
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
					0 liveindicator,
					0 modds,
					b.custid,
					0 livehomescore,
					0 liveawayscore,
					0 finalhomescore,
					0 finalawayscore,
					0 leagueid,
					m.sporttype,
					b.ip,
					b.betfrom,
					b.matchid,
					CONVERT(BIT,0) AS IsNeutral,
					(b.winlost - b.actual_stake) AS winlost,
					b.playercomm AS Commission,
					(b.scomm - b.acomm) AS scomm,
					(b.acomm - b.comm) AS acomm,
					(b.comm - b.playercomm) AS comm,
					b.awinlost,
					b.mwinlost,
					b.swinlost,
					'' AS ShowTime,
					b.winlostdate,
					'' betcheck,
					'' AS TransDesc,
					0 AS OddsSpread,
					0 AS OriginalBetType,
					-1 AS BetdaqId,
					b.ExtraInfo,
					0 AS WalletType,
					0 AS RefCode
				FROM dbo.bettrans AS b WITH (NOLOCK)
					INNER JOIN @SportBettype AS s ON s.BetType = b.bettype
					INNER JOIN dbo.match3rd AS m WITH (NOLOCK) ON b.matchid = m.match3rdid
				WHERE b.transid = @TransId
			END

			-- Get related Bonus/Cash tickets
			IF EXISTS (SELECT 1 FROM @Data WHERE RefCode <> 0)
			BEGIN
				INSERT INTO @Data
				SELECT
					b.bettype,
					b.transid,
					ISNULL(b.betid, 0) AS BetId,
					b.refno,
					m.matchcode,
					'' AS Race,
					m.GlobalShowTime AS EventDate,
					0 AS virtualrate,
					0 AS isShowOTExRate,
					b.sdiscount,
					b.adiscount,
					b.discount,
					m.homeid,
					m.awayid,
					ISNULL(b.checktime,'') settleTime,
					b.hdp1,
					b.hdp2,
					b.odds,
					0 AS finalodds,
					0 AS finalodds2,
					b.oddstype,
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
					b.betfrom,
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
					m.showtime,
					b.winlostdate,
					b.BetCheck,
					ISNULL(b.transdesc, '') AS TransDesc,
					ISNULL(b.oddsspread, 0) AS OddsSpread,
					0 AS OriginalBetType,
					-1 AS BetdaqId,
					ISNULL(b.ExtraInfo, '') AS ExtraInfo,
					ISNULL(b.WalletType, 0) AS WalletType,
					ISNULL(b.RefCode, 0) AS RefCode
				FROM
					dbo.bettrans AS b WITH (NOLOCK)
					INNER JOIN @Data AS b1
						ON b.custid = b1.CustId
						AND b.winlostdate = b1.WinLostDate
						AND b.RefCode = b1.RefCode
						AND b.transid <> b1.TransId
					INNER JOIN dbo.match AS m WITH (NOLOCK) ON b.matchid = m.matchid
			END
		END

		-- Bettrans14
		ELSE IF @WinLostDate <= @MoveBetsDay AND @WinLostDate >= @BalanceUpDay
		BEGIN
			-- Sportbooks, Number Game, Virtual Sports, Betradar Virtual Sports, Cash Out
			IF EXISTS (SELECT TOP(1) 1 FROM @SportBettype WHERE EventType = 1 AND BetType = @BetType )
			BEGIN
				INSERT INTO @Data
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
					0 AS virtualrate,
					0 AS isShowOTExRate,
					b.sdiscount,
					b.adiscount,
					b.discount,
					m.homeid,
					m.awayid,
					ISNULL(b.checktime,'') settleTime,
					b.hdp1,
					b.hdp2,
					b.odds,
					0 AS finalodds,
					0 AS finalodds2,
					b.OddsType,
					b.status,
					0 AS SettlementStatus,
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
					b.betfrom,
					b.matchid,
					ISNULL(m.IsNeutral, CONVERT(BIT,0)) AS IsNeutral,
					(b.winlost - b.actual_stake) AS winlost,
					b.playercomm AS Commission,
					(b.scomm - b.acomm) AS scomm,
					(b.acomm - b.comm) AS acomm,
					(b.comm - b.playercomm) AS comm,
					b.awinlost,
					b.mwinlost,
					b.swinlost,
					CASE
						WHEN s.ProductID IN (5, 27) THEN CONVERT(NVARCHAR(50), m.kickofftime)
						ELSE m.showtime
					END AS ShowTime,
					b.winlostdate,
					b.BetCheck,
					ISNULL(b.transdesc, '') AS TransDesc,
					ISNULL(b.oddsspread, 0) AS OddsSpread,
					0 AS OriginalBetType,
					CASE
						WHEN s.ProductID = 1 THEN ISNULL(b.betdaqid, -1)
						ELSE -1
					END AS BetdaqId,
					CASE
						WHEN s.ProductID = 1 THEN ISNULL(b.ExtraInfo, '')
						ELSE ''
					END AS ExtraInfo,
					CASE
						WHEN s.ProductID = 1 THEN ISNULL(b.WalletType, 0)
						ELSE 0
					END AS WalletType,
					CASE
						WHEN s.ProductID = 1 THEN ISNULL(b.RefCode, 0)
						ELSE 0
					END AS RefCode
				FROM dbo.bettrans14 AS b WITH (NOLOCK)
					INNER JOIN @SportBettype AS s ON s.Bettype = b.bettype
					INNER JOIN dbo.match14 AS m WITH (NOLOCK) ON b.matchid = m.matchid
				WHERE s.EventType = 1 AND b.transid = @TransId
			END

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
					INNER JOIN dbo.bettrans14 AS ob WITH (NOLOCK) ON b.RefNo = ob.transid
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
					INNER JOIN dbo.bettrans14 AS ob WITH (NOLOCK) ON b.RefNo = ob.transid
					LEFT JOIN dbo.bettrans14 AS cb WITH (NOLOCK)
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
					INNER JOIN dbo.bettrans14 AS ob WITH (NOLOCK) ON b.RefNo = ob.transid
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
					INNER JOIN dbo.bettrans14 AS cob WITH (NOLOCK) ON b.RefNo = cob.transid
					INNER JOIN dbo.bettrans14 AS ob WITH (NOLOCK) ON cob.RefNo = ob.transid
					LEFT JOIN dbo.bettrans14 AS cb WITH (NOLOCK)
						ON b.RefNo = cb.refno
						AND cb.BetType = 913
						AND cb.custid = @CustId
						AND cb.winlostdate = @WinLostDate
				WHERE b.BetType = 912
			END

			-- Mix Parlay, Combination Mix Parlay
			IF @BetType IN (9, 29, 2799)
			BEGIN
				INSERT INTO @Data
				SELECT
					b.bettype,
					CASE
						WHEN b.bettype = 29 AND ISNULL(b.betid, 0) > 0 THEN b.betid
						ELSE b.transid
					END AS TransId,
					ISNULL(b.betid, 0) AS BetId,
					b.refno,
					'' AS MatchCode,
					'' AS Race,
					'' AS EventDate,
					0 AS VirtualRate,
					0 AS IsShowOTExRate,
					b.sdiscount,
					b.adiscount,
					b.discount,
					0 AS HomeId,
					0 AS AwayId,
					'' AS SettleTime,
					b.hdp1,
					b.hdp2,
					b.odds,
					0 AS FinalOdds,
					0 AS FinalOdds2,
					0 AS OddsType,
					b.status,
					0 AS SettlementStatus,
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
					0 AS LiveIndicator,
					b.modds,
					b.custid,
					b.livehomescore,
					b.liveawayscore,
					0 AS FinalHomeScore,
					0 AS FinalAwayScore,
					0 AS LeagueId,
					0 AS SportType,
					b.ip,
					b.betfrom,
					0 AS MatchId,
					CONVERT(BIT, 0) AS IsNeutral,
					(b.winlost - b.actual_stake) AS WinLost,
					b.playercomm AS Commission,
					(b.scomm - b.acomm) AS SComm,
					(b.acomm - b.comm) AS AComm,
					(b.comm - b.playercomm) AS Comm,
					b.awinlost,
					b.mwinlost,
					b.swinlost,
					'' AS ShowTime,
					b.winlostdate,
					b.betcheck,
					'' AS TransDesc,
					0 AS OddsSpread,
					0 AS OriginalBetType,
					-1 AS BetdaqId,
					CASE
						WHEN b.bettype = 29 THEN ISNULL(b.ExtraInfo, '')
						ELSE ''
					END AS ExtraInfo,
					0 AS WalletType,
					0 AS RefCode
				FROM dbo.bettrans14 AS b WITH (NOLOCK)
				WHERE b.transid = @TransId AND b.bettype IN (9, 29, 2799)
			END

			-- Outright
			IF @BetType = 10
			BEGIN
				INSERT INTO @Data
				SELECT 
					b.bettype,
					b.transid,
					ISNULL(b.BetID,0) AS BetId,
					b.refno,
					odds.matchcode, 
					odds.groupmatch AS race,
					odds.eventdate,
					0 AS virtualrate,
					0 AS isShowOTExRate,
					b.sdiscount,
					b.adiscount,
					b.discount,
					0 AS homeid,
					odds.teamid AS awayid,
					'' settleTime, 
					b.hdp1,
					b.hdp2,
					b.odds,
					0 AS finalodds,
					0 AS finalodds2,
					b.oddstype AS OddsType,
					b.status,
					0 AS SettlementStatus,
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
					0,
					0,
					odds.leagueid,
					l.sporttype,
					b.ip,
					b.betfrom,
					b.matchid,
					CONVERT(BIT,0) AS IsNeutral,
					(b.winlost-b.actual_stake)  winlost,
					b.playercomm AS Commission,
					(b.scomm - b.acomm) AS scomm,
					(b.acomm - b.comm) AS acomm,
					(b.comm - b.playercomm) AS comm,
					b.awinlost,
					b.mwinlost,
					b.swinlost,
					'' AS showtime,
					b.winlostdate,
					b.BetCheck,
					'' AS TransDesc,
					0 AS OddsSpread,
					0 AS OriginalBetType,
					-1 AS BetdaqId,
					'' AS ExtraInfo,
					0 AS WalletType,
					0 AS RefCode
				FROM dbo.bettrans14 AS b WITH (NOLOCK)
					INNER JOIN dbo.outright14 AS odds WITH (NOLOCK) ON b.matchid = odds.orid
					INNER JOIN dbo.league l WITH (NOLOCK) ON odds.leagueid = l.leagueid
				WHERE b.bettype = 10
					AND b.transid = @TransId
			END

			-- Virtual Horse Racing
			IF EXISTS(SELECT TOP(1) 1 FROM @SportBettype WHERE ProductID = 5 AND EventType = 3 AND BetType = @BetType)
			BEGIN
				INSERT INTO @Data
				SELECT 
					b.bettype,
					b.transid,
					'' AS BetId,
					b.refno,
					o.RacerNum matchcode, --Horse Number
					b.oddsid AS Race, --Outright ID
					'' eventdate,
					0 AS virtualrate,
					0 AS isShowOTExRate,
					b.sdiscount,
					b.adiscount,
					b.discount,
					o.RacerID AS homeID,
					0 AS awayID,
					'' settleTime,
					b.hdp1,
					b.hdp2,
					b.odds,
					0 AS finalodds,
					0 AS finalodds2,
					b.OddsType,
					b.status,
					0 AS SettlementStatus,
					CASE WHEN b.comstatus = '1' THEN 1 ELSE 0 END AS comstatus,
					b.stake,
					b.actual_stake,
					b.transdate,
					'' betteam, 
					CASE WHEN b.bettype = 1233 THEN bm.spositiontaking ELSE b.spositiontaking END,
					CASE WHEN b.bettype = 1233 THEN bm.mpositiontaking ELSE b.mpositiontaking END,
					CASE WHEN b.bettype = 1233 THEN bm.apositiontaking ELSE b.apositiontaking END,
					CASE WHEN b.bettype = 1233 THEN bm.spositiontaking2 ELSE 0 END,
					CASE WHEN b.bettype = 1233 THEN bm.mpositiontaking2 ELSE 0 END,
					CASE WHEN b.bettype = 1233 THEN bm.apositiontaking2 ELSE 0 END,
					0 liveindicator,
					b.modds,
					b.custid,
					b.livehomescore, 
					b.liveawayscore, 
					0 finalhomescore, 
					0 finalawayscore, 
					r.leagueid,
					r.sporttype,
					b.ip,
					b.betfrom,
					b.matchid,
					CONVERT(BIT, 0) AS IsNeutral,
					(b.winlost - b.actual_stake) AS WinLost,
					b.playercomm AS Commission,
					(b.scomm - b.acomm) AS scomm,
					(b.acomm - b.comm) AS acomm,
					(b.comm - b.playercomm) AS comm,
					b.awinlost,
					b.mwinlost,
					b.swinlost,
					r.EventTime showtime, -- Race Name
					b.winlostdate,
					b.BetCheck,
					 '' AS TransDesc,
					 0 AS OddsSpread,
					0 AS OriginalBetType,
					-1 AS BetdaqId,
					'' AS ExtraInfo,
					0 AS WalletType,
					0 AS RefCode
				FROM 
					dbo.bettrans14 AS b WITH (NOLOCK)
					INNER JOIN dbo.VSOutright14 AS o WITH (NOLOCK) ON b.oddsid = o.Orid
					INNER JOIN dbo.VSRaceInfo14 AS r WITH (NOLOCK) ON r.EventID = o.EventID
					INNER JOIN @SportBettype AS s ON s.BetType = b.BetType 
					LEFT JOIN (
						SELECT 
							t.refno, 
							t.apositiontaking,
							t.mpositiontaking,
							t.spositiontaking,
							f.apositiontaking apositiontaking2,
							f.mpositiontaking mpositiontaking2,
							f.spositiontaking spositiontaking2
						FROM dbo.bettransm14 AS t WITH (NOLOCK)
							INNER JOIN dbo.bettransm14 AS f WITH (NOLOCK) ON t.refno = f.refno
						WHERE t.bettype = 1231 AND f.bettype = 1232 
						) bm ON b.refno = bm.refno
				WHERE b.transid = @TransId
					AND s.ProductID = 5
					AND s.EventType = 3
			END

			-- RNG Casino, Keno, Gold Deluxe, AG Casino, AllBet, Macau Games, NG2, Fishing World, Lottery, Pragmatic Casino
			-- Card Club, NPH Promotion, Spadegaming, Virtual Games, SA Gaming, Indo 4D, Sexy Gaming, Saba.club, Table Games, BBIN
			-- IBCBet Live Casino, RNG War, ION, PG Soft, Joker, WM, GDG, Leap Gaming Virtual Sports, Big Gaming, Happy 5 Linked Games (Number Game)
			-- MaxGame, Habanero, CG, Sports Lottery, PP Live Casino, VGaming, AdvantPlay, AdvantPlay Mini
			IF EXISTS (SELECT TOP(1) 1 FROM @SportBettype
						WHERE Bettype = @BetType
							AND (ProductID IN (6, 8, 11, 12, 21, 22, 23, 24, 28, 32, 34, 36, 37, 38, 39, 40, 42, 43, 45, 46, 47, 49, 50, 51, 52, 55, 56, 57, 59, 60, 61, 62, 63, 65, 66, 67, 68))
									OR (ProductID = 3 AND EventType = 0))
			BEGIN
				INSERT INTO @Data
				SELECT
					b.bettype,
					b.transid,
					ISNULL(b.betid, 0) AS BetId,
					b.refno,
					'' AS matchcode,
					'' AS Race,
					'' AS eventdate,
					0 AS virtualrate,
					0 AS isShowOTExRate,
					b.sdiscount,
					b.adiscount,
					b.discount,
					0 AS homeid,
					0 AS awayid,
					'' AS settleTime,
					CASE
						WHEN s.ProductId = 23 THEN b.hdp1
						ELSE 0
					END AS hdp1,
					CASE
						WHEN s.ProductId = 23 THEN b.hdp2
						ELSE 0
					END AS hdp2,
					CASE
						WHEN s.ProductID IN (3, 6, 8, 12, 23, 28, 32, 38, 40, 42, 43, 49, 63, 66) THEN b.odds
						ELSE 0
					END AS odds,
					0 AS finalodds,
					0 AS finalodds2,
					0 AS OddsType,
					CASE
						WHEN s.ProductID = 40 AND b.status = 'Won' AND b.modds = 0.25 THEN 'Half Won'
						WHEN s.ProductID = 40 AND b.status = 'Lose' AND b.modds = -0.25 THEN 'Half Lose'
						ELSE b.status
					END AS status,
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
					CASE
						WHEN s.ProductId = 23 THEN b.livehomescore
						ELSE 0
					END AS livehomescore,
					0 AS LiveAwayScore,
					0 AS finalhomescore,
					0 AS finalawayscore,
					0 AS leagueid,
					CASE
						WHEN s.ProductID IN (3, 6, 34, 36, 37, 38, 39, 40, 42, 43, 45, 46, 47, 49, 51, 52, 55, 56, 57, 59, 60, 61, 62, 63, 65, 66, 67, 68) THEN b.matchid
						WHEN s.ProductID = 8 THEN 202
						WHEN s.ProductID = 11 THEN 250
						WHEN s.ProductID = 12 THEN 255
						WHEN s.ProductID = 21 THEN 211
						WHEN s.ProductID = 22 THEN 212
						WHEN s.ProductID = 23 AND s.Bettype BETWEEN 2501 AND 2539 THEN 213
						WHEN s.ProductID = 23 AND s.Bettype BETWEEN 2541 AND 2579 THEN 214
						WHEN s.ProductID = 23 AND s.Bettype BETWEEN 2581 AND 2619 THEN 215
						WHEN s.ProductID = 23 AND s.Bettype BETWEEN 2621 AND 2659 THEN 216
						WHEN s.ProductID = 23 AND s.Bettype BETWEEN 2681 AND 2699 THEN 218
						WHEN s.ProductID = 24 THEN 219
						WHEN s.ProductID = 28 THEN 220
						WHEN s.ProductID = 32 THEN 248
						ELSE 0
					END AS SportType,
					b.ip,
					b.betfrom,
					CASE
						WHEN s.ProductID = 12 THEN b.matchid
						WHEN s.ProductID = 23 THEN b.betdaqid
						ELSE 0
					END AS MatchId,
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
					CASE
						WHEN s.ProductID IN (3, 12, 38, 63) THEN b.betcheck
						WHEN s.ProductId = 8 THEN ISNULL(b.comstatus, '')
						ELSE ''
					END AS BetCheck,
					CASE
						WHEN s.ProductID IN (3, 6, 8, 22, 23, 24, 28, 32, 34, 36, 38, 40, 43, 49, 55, 56, 61, 62, 63, 67, 68) THEN b.transdesc
						ELSE ''
					END AS TransDesc,
					CASE
						WHEN s.ProductID IN (6, 32, 42, 66) THEN ISNULL(b.oddsspread, 0)
						ELSE 0
					END AS OddsSpread,
					0 AS OriginalBetType,
					-1 AS BetdaqId,
					CASE
						WHEN s.ProductID IN (37, 49) THEN ISNULL(b.ExtraInfo, '')
						ELSE ''
					END AS ExtraInfo,
					0 AS WalletType,
					0 AS RefCode
				FROM dbo.bettrans14 AS b WITH (NOLOCK)
					INNER JOIN @SportBettype AS s ON s.Bettype = b.bettype
				WHERE b.transid = @TransID
					AND (s.ProductID IN (6, 8, 11, 12, 21, 22, 23, 24, 28, 32, 34, 36, 37, 38, 39, 40, 42, 43, 45, 46, 47, 49, 50, 51, 52, 55, 56, 57, 59, 60, 61, 62, 63, 65, 66, 67, 68)
							OR (s.ProductID = 3 AND s.EventType = 0))
			END

			-- Colossus Bet
			IF EXISTS (SELECT TOP(1) 1 FROM @SportBettype WHERE ProductID = 15 AND Bettype = @BetType)
			BEGIN
				INSERT INTO @Data
				SELECT
					b.bettype,
					b.transid,
					ISNULL(b.betid, 0) AS BetId,
					b.refno,
					'' AS matchcode,
					'' AS Race,
					'' AS eventdate,
					0 AS virtualrate,
					0 AS isShowOTExRate,
					b.sdiscount,
					b.adiscount,
					b.discount,
					0 AS homeid,
					0 AS awayid,
					'' AS settleTime,
					0 AS hdp1,
					0 AS hdp2,
					0 AS odds,
					0 AS finalodds,
					0 AS finalodds2,
					0 AS OddsType,
					b.status,
					0 AS SettlementStatus,
					CASE WHEN b.comstatus = '1' THEN 1 ELSE 0 END AS comstatus,
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
					204 AS SportType,
					b.ip,
					b.betfrom,
					0 AS MatchId,
					CONVERT(BIT, 0) AS IsNeutral,
					(b.winlost - b.actual_stake) winlost,
					b.playercomm AS Commission,
					(b.scomm - b.acomm) AS scomm,
					(b.acomm - b.comm) AS acomm,
					(b.comm - b.playercomm) AS comm,
					b.awinlost,
					b.mwinlost,
					b.swinlost,
					'' AS showtime,
					b.winlostdate ,
					ISNULL(bm.betcheck, '') AS BetCheck,
					'' AS TransDesc,
					0 AS OddsSpread,
					0 AS OriginalBetType,
					-1 AS BetdaqId,
					'' AS ExtraInfo,
					0 AS WalletType,
					0 AS RefCode
				FROM dbo.bettrans14 AS b WITH (NOLOCK)
					INNER JOIN @SportBettype AS s ON s.Bettype = b.bettype
					LEFT JOIN dbo.bettransm14 AS bm WITH (NOLOCK) ON b.refno = bm.refno AND bm.bettype = 18001
				WHERE b.transid = @TransId
					AND s.ProductID = 15
			END

			-- Bitcoin
			IF EXISTS (SELECT TOP(1) 1 FROM @SportBettype WHERE ProductID = 69 AND BetType = @BetType)
			BEGIN
				INSERT INTO @Data
				SELECT
					b.bettype,
					b.transid,
					0 AS BetId,
					b.refno,
					'' matchcode,
					'' AS Race,
					m.EndTime AS EventDate,
					0 AS VirtualRate,
					0 AS IsShowOTExRate,
					b.sdiscount,
					b.adiscount,
					b.discount,
					0 homeid,
					0 awayid,
					'' AS SettleTime,
					b.hdp1,
					0 hdp2,
					b.odds,
					0 AS finalodds,
					0 AS finalodds2,
					b.OddsType,
					b.status,
					0 AS SettlementStatus,
					0 AS comstatus,
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
					0 liveindicator,
					0 modds,
					b.custid,
					0 livehomescore,
					0 liveawayscore,
					0 finalhomescore,
					0 finalawayscore,
					0 leagueid,
					m.sporttype,
					b.ip,
					b.betfrom,
					b.matchid,
					CONVERT(BIT,0) AS IsNeutral,
					(b.winlost - b.actual_stake) AS winlost,
					b.playercomm AS Commission,
					(b.scomm - b.acomm) AS scomm,
					(b.acomm - b.comm) AS acomm,
					(b.comm - b.playercomm) AS comm,
					b.awinlost,
					b.mwinlost,
					b.swinlost,
					''  AS ShowTime,
					b.winlostdate,
					'' betcheck,
					'' AS TransDesc,
					0 AS OddsSpread,
					0 AS OriginalBetType,
					-1 AS BetdaqId,
					b.ExtraInfo,
					0 AS WalletType,
					0 AS RefCode
				FROM dbo.bettrans14 AS b WITH (NOLOCK)
					INNER JOIN @SportBettype AS s ON s.BetType = b.bettype
					INNER JOIN dbo.match3rd14 AS m WITH (NOLOCK) ON b.matchid = m.match3rdid
				WHERE b.transid = @TransId
			END

			-- Get related Bonus/Cash tickets
			IF EXISTS (SELECT 1 FROM @Data WHERE RefCode <> 0)
			BEGIN
				INSERT INTO @Data
				SELECT
					b.bettype,
					b.transid,
					ISNULL(b.betid, 0) AS BetId,
					b.refno,
					m.matchcode,
					'' AS Race,
					m.GlobalShowTime AS EventDate,
					0 AS virtualrate,
					0 AS isShowOTExRate,
					b.sdiscount,
					b.adiscount,
					b.discount,
					m.homeid,
					m.awayid,
					ISNULL(b.checktime,'') settleTime,
					b.hdp1,
					b.hdp2,
					b.odds,
					0 AS finalodds,
					0 AS finalodds2,
					b.oddstype,
					b.status,
					0 AS SettlementStatus,
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
					b.betfrom,
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
					m.showtime,
					b.winlostdate,
					b.BetCheck,
					ISNULL(b.transdesc, '') AS TransDesc,
					ISNULL(b.oddsspread, 0) AS OddsSpread,
					0 AS OriginalBetType,
					-1 AS BetdaqId,
					ISNULL(b.ExtraInfo, '') AS ExtraInfo,
					ISNULL(b.WalletType, 0) AS WalletType,
					ISNULL(b.RefCode, 0) AS RefCode
				FROM
					dbo.bettrans14 AS b WITH (NOLOCK)
					INNER JOIN @Data AS b1
						ON b.custid = b1.CustId
						AND b.winlostdate = b1.WinLostDate
						AND b.RefCode = b1.RefCode
						AND b.transid <> b1.TransId
					INNER JOIN dbo.match14 AS m WITH (NOLOCK) ON b.matchid = m.matchid
			END
		END

		-- Bettrans_bk
		ELSE IF @WinLostDate < @BalanceUpDay
		BEGIN
			-- Sportbooks, Number Game, Live Casino, Virtual Sports, Betradar Virtual Sports, Cash Out
			IF EXISTS (SELECT TOP(1) 1 FROM @SportBettype WHERE EventType = 1 AND BetType = @BetType )
			BEGIN
				INSERT INTO @Data
				SELECT
					b.bettype,
					b.transid,
					ISNULL(b.BetID,0) AS BetId,
					b.refno,
					m.matchcode,
					'' AS Race,
					CASE
						WHEN s.ProductID IN (1, 25) THEN m.GlobalShowTime
						ELSE m.eventdate
					END AS EventDate,
					0 AS virtualrate,
					0 AS isShowOTExRate,
					b.sdiscount,
					b.adiscount,
					b.discount,
					m.homeid,
					m.awayid,
					ISNULL(b.checktime,'') settleTime,
					b.hdp1,
					b.hdp2,
					b.odds,
					0 AS finalodds,
					0 AS finalodds2,
					b.OddsType,
					b.status,
					0 AS SettlementStatus,
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
					dp.ip,
					b.betfrom,
					b.matchid,
					ISNULL(m.isNeutral, CONVERT(BIT,0)) AS IsNeutral,
					(b.winlost-b.actual_stake)  winlost,
					b.playercomm AS Commission,
					(b.scomm - b.acomm) AS scomm,
					(b.acomm - b.comm) AS acomm,
					(b.comm - b.playercomm) AS comm,
					b.awinlost,
					b.mwinlost,
					b.swinlost,
					CASE
						WHEN s.ProductID IN (5, 27) THEN CONVERT(NVARCHAR(50), m.kickofftime)
						ELSE m.showtime
					END AS ShowTime,
					b.winlostdate,
					b.BetCheck,
					ISNULL(b.transdesc, '') AS TransDesc,
					ISNULL(b.oddsspread, 0) AS OddsSpread,
					0 AS OriginalBetType,
					CASE
						WHEN s.ProductID = 1 THEN ISNULL(b.betdaqid, -1)
						ELSE -1
					END AS BetdaqId,
					CASE
						WHEN s.ProductID = 1 THEN ISNULL(b.ExtraInfo, '')
						ELSE ''
					END AS ExtraInfo,
					CASE
						WHEN s.ProductID = 1 THEN ISNULL(b.WalletType, 0)
						ELSE 0
					END AS WalletType,
					CASE
						WHEN s.ProductID = 1 THEN ISNULL(b.RefCode, 0)
						ELSE 0
					END AS RefCode
				FROM
					bodb_Archive.dbo.bettrans_bk AS b WITH (NOLOCK)
					CROSS APPLY dbo.f_IP_Decompress(b.Ip) AS dp
					INNER JOIN @SportBettype AS s ON s.BetType = b.BetType
					INNER JOIN bodb_Archive.dbo.match_bk AS m WITH (NOLOCK) ON b.matchid = m.matchid
				WHERE s.EventType = 1 AND b.transid = @TransId

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
						INNER JOIN bodb_Archive.dbo.bettrans_bk AS ob WITH (NOLOCK) ON b.RefNo = ob.transid
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
						INNER JOIN bodb_Archive.dbo.bettrans_bk AS ob WITH (NOLOCK) ON b.RefNo = ob.transid
						LEFT JOIN bodb_Archive.dbo.bettrans_bk AS cb WITH (NOLOCK)
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
						INNER JOIN bodb_Archive.dbo.bettrans_bk AS ob WITH (NOLOCK) ON b.RefNo = ob.transid
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
						INNER JOIN bodb_Archive.dbo.bettrans_bk AS cob WITH (NOLOCK) ON b.RefNo = cob.transid
						INNER JOIN bodb_Archive.dbo.bettrans_bk AS ob WITH (NOLOCK) ON cob.RefNo = ob.transid
						LEFT JOIN bodb_Archive.dbo.bettrans_bk AS cb WITH (NOLOCK)
							ON b.RefNo = cb.refno
							AND cb.bettype = 913
							AND cb.custid = @CustId
							AND cb.winlostdate = @WinLostDate
					WHERE b.BetType = 912
				END
			END

			-- Mix Parlay, Combination Mix Parlay, Mix Parlay (Betradar Virtual Sports)
			IF @BetType IN (9, 29, 2799)
			BEGIN
				INSERT INTO @Data
				SELECT
					b.bettype,
					CASE
						WHEN b.bettype = 29 AND ISNULL(b.betid, 0) > 0 THEN b.betid
						ELSE b.transid
					END AS TransId,
					ISNULL(b.betid, 0) AS BetId,
					b.refno,
					'' AS MatchCode,
					'' AS Race,
					'' AS EventDate,
					0 AS VirtualRate,
					0 AS IsShowOTExRate,
					b.sdiscount,
					b.adiscount,
					b.discount,
					0 AS HomeId,
					0 AS AwayId,
					'' AS SettleTime,
					b.hdp1,
					b.hdp2,
					b.odds,
					0 AS FinalOdds,
					0 AS FinalOdds2,
					0 AS OddsType,
					b.status,
					0 AS SettlementStatus,
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
					0 AS LiveIndicator,
					b.modds,
					b.custid,
					b.livehomescore,
					b.liveawayscore,
					0 AS FinalHomeScore,
					0 AS FinalAwayScore,
					0 AS LeagueId,
					0 AS SportType,
					dp.ip,
					b.betfrom,
					0 AS MatchId,
					CONVERT(BIT, 0) AS IsNeutral,
					(b.winlost - b.actual_stake) AS WinLost,
					b.playercomm AS Commission,
					(b.scomm - b.acomm) AS SComm,
					(b.acomm - b.comm) AS AComm,
					(b.comm - b.playercomm) AS Comm,
					b.awinlost,
					b.mwinlost,
					b.swinlost,
					'' AS ShowTime,
					b.winlostdate,
					b.betcheck,
					'' AS TransDesc,
					0 AS bettrans14,
					0 AS OriginalBetType,
					-1 AS BetdaqId,
					CASE
						WHEN b.bettype = 29 THEN ISNULL(b.ExtraInfo, '')
						ELSE ''
					END AS ExtraInfo,
					0 AS WalletType,
					0 AS RefCode
				FROM bodb_Archive.dbo.bettrans_bk AS b WITH (NOLOCK)
				CROSS APPLY dbo.f_IP_Decompress(b.Ip) AS dp
				WHERE b.transid = @TransId AND b.bettype IN (9, 29, 2799)
			END

			-- Outright
			IF @BetType = 10
			BEGIN
				INSERT INTO @Data
				SELECT
					b.bettype,
					b.transid,
					ISNULL(b.BetID,0) AS BetId,
					b.refno,
					odds.matchcode,
					odds.groupmatch AS race,
					odds.eventdate,
					0 AS virtualrate,
					0 AS isShowOTExRate,
					b.sdiscount,
					b.adiscount,
					b.discount,
					0 AS homeid,
					odds.teamid AS awayid,
					'' settleTime, 
					b.hdp1,
					b.hdp2,
					b.odds,
					0 AS finalodds,
					0 AS finalodds2,
					b.oddstype AS OddsType,
					b.status,
					0 AS SettlementStatus,
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
					0,
					0,
					odds.leagueid,
					l.sporttype,
					dp.ip,
					b.betfrom,
					b.matchid,
					CONVERT(BIT,0) AS IsNeutral,
					(b.winlost-b.actual_stake)  winlost,
					b.playercomm AS Commission,
					(b.scomm - b.acomm) AS scomm,
					(b.acomm - b.comm) AS acomm,
					(b.comm - b.playercomm) AS comm,
					b.awinlost,
					b.mwinlost,
					b.swinlost,
					'' AS showtime,
					b.winlostdate,
					b.BetCheck,
					'' AS TransDesc,
					0 AS OddsSpread,
					0 AS OriginalBetType,
					-1 AS BetdaqId,
					'' AS ExtraInfo,
					0 AS WalletType,
					0 AS RefCode
				FROM bodb_Archive.dbo.bettrans_bk AS b WITH (NOLOCK)
					CROSS APPLY dbo.f_IP_Decompress(b.Ip) AS dp
					INNER JOIN bodb_Archive.dbo.outright_bk AS odds WITH (NOLOCK) ON b.matchid = odds.orid
					INNER JOIN dbo.league AS l WITH (NOLOCK) ON odds.leagueid = l.leagueid
				WHERE b.bettype = 10
					AND b.transid = @TransId
			END

			-- Virtual Horse Racing
			IF EXISTS(SELECT TOP(1) 1 FROM @SportBettype WHERE ProductID = 5 AND EventType = 3 AND BetType = @BetType)
			BEGIN
				INSERT INTO @Data
				SELECT 
					b.bettype,
					b.transid,
					'' AS BetId,
					b.refno,
					o.RacerNum matchcode, --Horse Number
					b.oddsid AS Race, --Outright ID
					'' eventdate,
					0 AS virtualrate,
					0 AS isShowOTExRate,
					b.sdiscount,
					b.adiscount,
					b.discount,
					o.RacerID AS homeID,
					0 AS awayID,
					'' settleTime,
					b.hdp1,
					b.hdp2,
					b.odds,
					0 AS finalodds,
					0 AS finalodds2,
					b.OddsType,
					b.status,
					0 AS SettlementStatus,
					CASE WHEN b.comstatus = '1' THEN 1 ELSE 0 END AS comstatus,
					b.stake,
					b.actual_stake,
					b.transdate,
					'' betteam, 
					CASE WHEN b.bettype = 1233 THEN bm.spositiontaking ELSE b.spositiontaking END,
					CASE WHEN b.bettype = 1233 THEN bm.mpositiontaking ELSE b.mpositiontaking END,
					CASE WHEN b.bettype = 1233 THEN bm.apositiontaking ELSE b.apositiontaking END,
					CASE WHEN b.bettype = 1233 THEN bm.spositiontaking2 ELSE 0 END,
					CASE WHEN b.bettype = 1233 THEN bm.mpositiontaking2 ELSE 0 END,
					CASE WHEN b.bettype = 1233 THEN bm.apositiontaking2 ELSE 0 END,
					0 liveindicator,
					b.modds,
					b.custid,
					b.livehomescore, 
					b.liveawayscore, 
					0 finalhomescore, 
					0 finalawayscore, 
					r.leagueid,
					r.sporttype,
					dp.ip,
					b.betfrom,
					b.matchid,
					CONVERT (BIT, 0) AS IsNeutral,
					(b.winlost-b.actual_stake)  winlost,
					b.playercomm AS Commission,
					(b.scomm - b.acomm) AS scomm,
					(b.acomm - b.comm) AS acomm,
					(b.comm - b.playercomm) AS comm,
					b.awinlost,
					b.mwinlost,
					b.swinlost,
					r.EventTime AS ShowTime,
					b.winlostdate,
					b.BetCheck,
					 '' AS TransDesc,
					 0 AS OddsSpread,
					0 AS OriginalBetType,
					-1 AS BetdaqId,
					'' AS ExtraInfo,
					0 AS WalletType,
					0 AS RefCode
				FROM 
					bodb_Archive.dbo.bettrans_bk AS b WITH (NOLOCK) 
					CROSS APPLY dbo.f_IP_Decompress(b.Ip) AS dp
					INNER JOIN bodb_Archive.dbo.VSOutright_bk AS o WITH (NOLOCK) ON b.oddsid = o.Orid
					INNER JOIN bodb_Archive.dbo.VSRaceInfo_bk AS r WITH (NOLOCK) ON r.EventID = o.EventID
					INNER JOIN @SportBettype AS s ON s.BetType = b.BetType
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
						) bm ON b.refno = bm.refno
				WHERE b.transid = @TransId
					AND s.ProductID = 5
					AND s.EventType = 3
			END

			-- RNG Casino Single Wallet, AG Casino Single Wallet, AllBet, Voidbridge, NG2, Fishing World, Pragmatic Casino, Card Club, NPH Promotion
			-- Spadegaming, SA Gaming, Sexy Gaming, Saba.club, IBCBet Live Casino, BBIN, RNG War, ION, PG Soft, Joker, WM, GDG, Big Gaming, MaxGame
			-- Happy 5 Linked Games(Number Game), Habanero, CG, Sports Lottery, PP Live Casino, VGaming, AdvantPlay, AdvantPlay Mini
			IF EXISTS (SELECT TOP(1) 1 FROM @SportBettype
						WHERE Bettype = @BetType 
							AND (ProductID IN (11, 21, 22, 23, 24, 32, 34, 36, 37, 39, 42, 45, 46, 47, 50, 51, 52, 55, 56, 57, 59, 60, 61, 62, 63, 65, 66, 67, 68)
								OR (ProductID = 6 AND SubProduct <> '')
								OR (ProductID = 3 AND EventType = 0)))
			BEGIN
				INSERT INTO @Data
				SELECT
					b.bettype,
					b.transid,
					ISNULL(b.betid, 0) AS BetId,
					b.refno,
					'' AS matchcode,
					'' AS Race,
					'' AS eventdate,
					0 AS virtualrate,
					0 AS isShowOTExRate,
					b.sdiscount,
					b.adiscount,
					b.discount,
					0 AS homeid,
					0 AS awayid,
					'' AS settleTime,
					CASE
						WHEN s.ProductId = 23 THEN b.hdp1
						ELSE 0
					END AS hdp1,
					CASE
						WHEN s.ProductId = 23 THEN b.hdp2
						ELSE 0
					END AS hdp2,
					CASE
						WHEN s.ProductId IN (3, 6, 23, 32, 42, 63, 66) THEN b.odds
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
					CASE
						WHEN s.ProductId = 23 THEN b.livehomescore
						ELSE 0
					END AS livehomescore,
					0 AS LiveAwayScore,
					0 AS finalhomescore,
					0 AS finalawayscore,
					0 AS leagueid,
					CASE
						WHEN s.ProductID = 6 AND s.SubProduct <> '' THEN b.matchid
						WHEN s.ProductID = 11 THEN 250
						WHEN s.ProductID = 21 THEN 211
						WHEN s.ProductID = 22 THEN 212
						WHEN s.ProductID = 23 AND s.Bettype BETWEEN 2501 AND 2539 THEN 213
						WHEN s.ProductID = 23 AND s.Bettype BETWEEN 2541 AND 2579 THEN 214
						WHEN s.ProductID = 23 AND s.Bettype BETWEEN 2581 AND 2619 THEN 215
						WHEN s.ProductID = 23 AND s.Bettype BETWEEN 2621 AND 2659 THEN 216
						WHEN s.ProductID = 23 AND s.Bettype BETWEEN 2681 AND 2699 THEN 218
						WHEN s.ProductID = 24 THEN 219
						WHEN s.ProductID = 32 THEN 248
						WHEN s.ProductID IN (3, 34, 36, 37, 39, 42, 45, 46, 47, 51, 52, 55, 56, 57, 59, 60, 61, 62, 63, 65, 66, 67, 68) THEN b.matchid
						ELSE 0
					END AS SportType,
					dp.ip,
					b.betfrom,
					CASE
						WHEN s.ProductId = 23 THEN b.betdaqid
						ELSE 0
					END AS MatchId,
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
					CASE 
						WHEN s.ProductId IN (3, 63) THEN b.betcheck
						ELSE ''
					END AS BetCheck,
					CASE
						WHEN s.ProductID = 6 AND s.SubProduct <> '' THEN b.transdesc
						WHEN s.ProductID IN (3, 22, 23, 24, 32, 34, 36, 55, 56, 61, 62, 63, 67, 68) THEN b.transdesc
						ELSE ''
					END AS TransDesc,
					CASE
						WHEN s.ProductID IN (6, 32, 42, 66) THEN ISNULL(b.oddsspread, 0)
						ELSE 0
					END AS OddsSpread,
					0 AS OriginalBetType,
					-1 AS BetdaqId,
					CASE
						WHEN s.ProductID = 37 THEN ISNULL(b.ExtraInfo, '')
						ELSE ''
					END AS ExtraInfo,
					0 AS WalletType,
					0 AS RefCode
				FROM bodb_Archive.dbo.bettrans_bk AS b WITH (NOLOCK)
					CROSS APPLY dbo.f_IP_Decompress(b.Ip) AS dp
					INNER JOIN @SportBettype AS s ON s.Bettype = b.bettype
				WHERE b.transid = @TransID
					AND (s.ProductID IN (11, 21, 22, 23, 24, 32, 34, 36, 37, 39, 42, 45, 46, 47, 50, 51, 52, 55, 56, 57, 59, 60, 61, 62, 63, 65, 66, 67, 68)
						OR (s.ProductID = 6 AND s.SubProduct <> '')
						OR (s.ProductID = 3 AND s.EventType = 0))
			END

			-- Bitcoin
			IF EXISTS (SELECT TOP(1) 1 FROM @SportBettype WHERE ProductID = 69 AND BetType = @BetType)
			BEGIN
				INSERT INTO @Data
				SELECT
					b.bettype,
					b.transid,
					0 AS BetId,
					b.refno,
					'' matchcode,
					'' AS Race,
					m.EndTime AS EventDate,
					0 AS VirtualRate,
					0 AS IsShowOTExRate,
					b.sdiscount,
					b.adiscount,
					b.discount,
					0 homeid,
					0 awayid,
					'' AS SettleTime,
					b.hdp1,
					0 hdp2,
					b.odds,
					0 AS finalodds,
					0 AS finalodds2,
					b.OddsType,
					b.status,
					0 AS SettlementStatus,
					0 AS comstatus,
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
					0 liveindicator,
					0 modds,
					b.custid,
					0 livehomescore,
					0 liveawayscore,
					0 finalhomescore,
					0 finalawayscore,
					0 leagueid,
					m.sporttype,
					dp.ip,
					b.betfrom,
					b.matchid,
					CONVERT(BIT,0) AS IsNeutral,
					(b.winlost - b.actual_stake) AS winlost,
					b.playercomm AS Commission,
					(b.scomm - b.acomm) AS scomm,
					(b.acomm - b.comm) AS acomm,
					(b.comm - b.playercomm) AS comm,
					b.awinlost,
					b.mwinlost,
					b.swinlost,
					''  AS ShowTime,
					b.winlostdate,
					'' betcheck,
					'' AS TransDesc,
					0 AS OddsSpread,
					0 AS OriginalBetType,
					-1 AS BetdaqId,
					b.ExtraInfo,
					0 AS WalletType,
					0 AS RefCode
				FROM bodb_Archive.dbo.bettrans_bk AS b WITH (NOLOCK)
					CROSS APPLY dbo.f_IP_Decompress(b.Ip) AS dp
					INNER JOIN @SportBettype AS s ON s.BetType = b.bettype
					INNER JOIN bodb_Archive.dbo.match3rd_bk AS m WITH (NOLOCK) ON b.matchid = m.match3rdid
				WHERE b.transid = @TransId
			END

			-- Get related Bonus/Cash tickets
			IF EXISTS (SELECT 1 FROM @Data WHERE RefCode <> 0)
			BEGIN
				INSERT INTO @Data
				SELECT
					b.bettype,
					b.transid,
					ISNULL(b.betid, 0) AS BetId,
					b.refno,
					m.matchcode,
					'' AS Race,
					m.GlobalShowTime AS EventDate,
					0 AS virtualrate,
					0 AS isShowOTExRate,
					b.sdiscount,
					b.adiscount,
					b.discount,
					m.homeid,
					m.awayid,
					ISNULL(b.checktime,'') settleTime,
					b.hdp1,
					b.hdp2,
					b.odds,
					0 AS finalodds,
					0 AS finalodds2,
					b.oddstype,
					b.status,
					0 AS SettlementStatus,
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
					dp.ip,
					b.betfrom,
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
					m.showtime,
					b.winlostdate,
					b.BetCheck,
					ISNULL(b.transdesc, '') AS TransDesc,
					ISNULL(b.oddsspread, 0) AS OddsSpread,
					0 AS OriginalBetType,
					-1 AS BetdaqId,
					ISNULL(b.ExtraInfo, '') AS ExtraInfo,
					ISNULL(b.WalletType, 0) AS WalletType,
					ISNULL(b.RefCode, 0) AS RefCode
				FROM
					bodb_Archive.dbo.bettrans_bk AS b WITH (NOLOCK)
					CROSS APPLY dbo.f_IP_Decompress(b.Ip) AS dp
					INNER JOIN @Data AS b1
						ON b.custid = b1.CustId
						AND b.winlostdate = b1.WinLostDate
						AND b.RefCode = b1.RefCode
						AND b.transid <> b1.TransId
					INNER JOIN bodb_Archive.dbo.match_bk AS m WITH (NOLOCK) ON b.matchid = m.matchid
			END
		END
	END
	
	-- Don't display Cash text for ticket from Cash Wallet only
	UPDATE @Data
	SET WalletType = 0
	WHERE WalletType = 2 AND RefCode = 0

	-- Display Cash/Bonus text for ticket from multiple wallets
	UPDATE @Data
	SET RefCode = 0
	WHERE RefCode <> 0

	DECLARE @DetailData TABLE (
		RefNo			NVARCHAR(50),
		Odds			MONEY,
		Stake			MONEY,
		Status			NVARCHAR(50),
		APositionTaking SMALLMONEY,
		MPositionTaking SMALLMONEY,
		SPositionTaking SMALLMONEY,
		BetType			SMALLINT,
		BetTeam			NVARCHAR(50),
		TransDesc		VARCHAR(2000)
	)

	-- Virtual Sports
	IF EXISTS (	SELECT TOP(1) 1
				FROM @SportBettype AS sp
					INNER JOIN @Data AS d ON d.bettype = sp.bettype
				WHERE sp.ProductID = 5 AND sp.EventType = 3)
	BEGIN
		IF @WinLostDate > @MoveBetsDay
		BEGIN
			INSERT INTO @DetailData
			SELECT
				bm.refno,
				bm.odds,
				bm.stake,
				bm.status,
				bm.apositiontaking,
				bm.mpositiontaking,
				bm.spositiontaking,
				bm.bettype,
				bm.betteam,
				'' AS TransDesc
			FROM dbo.bettransm AS bm WITH (NOLOCK)
				INNER JOIN @SportBettype AS sp ON bm.bettype = sp.bettype
				INNER JOIN @Data AS b ON bm.custid = b.CustId AND bm.refno = b.RefNo
			WHERE sp.ProductID = 5 AND sp.EventType = 3
		END
		ELSE IF @WinLostDate <= @MoveBetsDay AND @WinLostDate >= @BalanceUpDay
		BEGIN
			INSERT INTO @DetailData
			SELECT
				bm.refno,
				bm.odds,
				bm.stake,
				bm.status,
				bm.apositiontaking,
				bm.mpositiontaking,
				bm.spositiontaking,
				bm.bettype,
				bm.betteam,
				'' AS TransDesc
			FROM dbo.bettransm14 AS bm WITH (NOLOCK)
				INNER JOIN @SportBettype AS sp ON bm.bettype = sp.bettype
				INNER JOIN @Data AS b ON bm.custid = b.CustId AND bm.refno = b.RefNo
			WHERE sp.ProductID = 5 AND sp.EventType = 3
		END
		ELSE
		BEGIN
			INSERT INTO @DetailData
			SELECT
				bm.refno,
				bm.odds,
				bm.stake,
				bm.status,
				bm.apositiontaking,
				bm.mpositiontaking,
				bm.spositiontaking,
				bm.bettype,
				bm.betteam,
				'' AS TransDesc
			FROM DBARC.bodb_Archive.dbo.bettransm AS bm WITH (NOLOCK)
				INNER JOIN @SportBettype AS sp ON bm.bettype = sp.bettype
				INNER JOIN @Data AS b ON bm.custid = b.CustId AND bm.refno = b.RefNo
			WHERE sp.ProductID = 5 AND sp.EventType = 3
		END
	END

	-- Gold Deluxe
	IF EXISTS (	SELECT TOP(1) 1
				FROM @SportBettype AS sp
					INNER JOIN @Data AS d ON d.bettype = sp.bettype 
				WHERE sp.ProductID = 12)
	BEGIN
		IF @WinLostDate > @MoveBetsDay
		BEGIN
			INSERT INTO @DetailData
			SELECT
				bg.refno,
				bg.odds,
				bg.stake,
				bg.status,
				bg.apositiontaking,
				bg.mpositiontaking,
				bg.spositiontaking,
				bg.bettype,
				bg.betteam,
				bg.TransDesc
			FROM dbo.bettransg AS bg WITH (NOLOCK)
				INNER JOIN @SportBettype AS sp ON bg.bettype = sp.bettype
				INNER JOIN @Data AS b ON bg.custid = b.CustId AND bg.refno = b.TransId AND bg.bettype = b.BetType
			WHERE sp.ProductID = 12
		END
		ELSE IF @WinLostDate <= @MoveBetsDay AND @WinLostDate >= @BalanceUpDay
		BEGIN
			INSERT INTO @DetailData
			SELECT
				bg.refno,
				bg.odds,
				bg.stake,
				bg.status,
				bg.apositiontaking,
				bg.mpositiontaking,
				bg.spositiontaking,
				bg.bettype,
				bg.betteam,
				bg.TransDesc
			FROM dbo.bettransg14 AS bg WITH (NOLOCK)
				INNER JOIN @SportBettype AS sp ON bg.bettype = sp.bettype
				INNER JOIN @Data AS b ON bg.custid = b.CustId AND bg.refno = b.TransId AND bg.bettype = b.BetType
			WHERE sp.ProductID = 12
		END
		ELSE
		BEGIN
			INSERT INTO @DetailData
			SELECT
				bg.refno,
				bg.odds,
				bg.stake,
				bg.status,
				bg.apositiontaking,
				bg.mpositiontaking,
				bg.spositiontaking,
				bg.bettype,
				bg.betteam,
				bg.TransDesc
			FROM bodb_Archive.dbo.bettransg AS bg WITH (NOLOCK)
				INNER JOIN @SportBettype AS sp ON bg.bettype = sp.bettype
				INNER JOIN @Data AS b ON bg.custid = b.CustId AND bg.refno = b.TransId AND bg.bettype = b.BetType
			WHERE sp.ProductID = 12
		END
	END

	-- BettransRnG tables
	SET @WinLostDate = NULL
	SET @CustId = NULL

	-- bettransRnG
	SELECT TOP(1)
		@TransId = b.transid,
		@BetType = b.gameID,
		@WinLostDate = b.winlostdate,
		@CustId = b.custid
	FROM dbo.bettransRnG AS b WITH (NOLOCK)
		INNER JOIN @SportBettype AS sp ON b.gameID = sp.bettype
	WHERE b.transid = @RefNo

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
	BEGIN
		-- bettransRnG
		IF @WinLostDate > @MoveBetsDay
		BEGIN
			-- RNG Casino Single Wallet, Macau Games, Fishing World, Pragmatic Casino, Card Club, Spadegaming, Saba.club, RNG War, PG Soft, Joker, MaxGame, Habanero, CG, VGaming
			-- AdvantPlay, AdvantPlay Mini
			IF EXISTS (	SELECT TOP(1) 1 FROM @SportBettype
						WHERE Bettype = @BetType
							AND (ProductID IN (22, 24, 32, 34, 36, 42, 50, 55, 56, 60, 61, 62, 66, 67, 68)
								OR (ProductID = 6 AND SubProduct <> '')))
			BEGIN
				INSERT INTO @Data
				SELECT
					b.gameID AS BetType,
					b.transid,
					0 AS BetId,
					b.refno,
					CASE
						WHEN s.productID IN (24, 32, 34, 36) THEN b.Additional
						WHEN s.productID IN (42, 61, 62, 66, 67, 68) THEN ISNULL(b.SiteID, '')
						WHEN s.ProductID IN (55, 56) THEN b.GameId3rd
						ELSE ''
					END AS MatchCode,
					'' AS Race,
					CASE
						WHEN s.productID IN (60) THEN b.Transdate3rd
						ELSE ''
					END AS EventDate,
					0 AS virtualrate,
					0 AS isShowOTExRate,
					b.sdiscount,
					b.adiscount,
					b.discount,
					0 AS homeid,
					0 AS awayid,
					'' AS settleTime,
					0 AS hdp1,
					0 AS hdp2,
					CASE
						WHEN s.ProductID IN (6, 32, 42, 66) AND b.statusID IN (111, 112, 113) THEN ISNULL(b.ContributionRate, 0)
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
					CASE
						WHEN s.productID IN (61, 62, 67, 68) THEN b.GameId3rd
					ELSE ''
					END AS betteam,
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
					b.betfrom,
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
						WHEN s.ProductID IN (6, 32, 42, 66) AND b.statusID IN (111, 112, 113) THEN ISNULL(b.BetStake, 0)
						ELSE 0
					END AS OddsSpread,
					0 AS OriginalBetType,
					CASE
						WHEN s.ProductID IN (6, 32, 42, 66) THEN ISNULL(b.RefNo2, -1)
						ELSE -1
					END AS BetdaqId,
					CASE
						WHEN s.ProductID IN (6, 32, 42, 66) THEN ISNULL(b.JackpotInfo, '')
						ELSE ''
					END AS ExtraInfo,
					0 AS WalletType,
					0 AS RefCode
				FROM dbo.bettransRnG AS b WITH (NOLOCK)
					INNER JOIN @SportBettype AS s ON s.Bettype = b.gameID
				WHERE b.transid = @TransId
					AND (s.ProductId IN (22, 24, 32, 34, 36, 42, 50, 55, 56, 60, 61, 62, 66, 67, 68)
						OR (s.ProductId = 6 AND s.SubProduct <> ''))
			END
		END

		-- bettransRnG14
		ELSE IF @WinLostDate BETWEEN @BalanceUpDay AND @MoveBetsDay
		BEGIN
			-- RNG Casino Single Wallet, Macau Games, Fishing World, Pragmatic Casino, Card Club, Spadegaming, Saba.club, RNG War, PG Soft, Joker, MaxGame, Habanero, CG, VGaming
			-- AdvantPlay, AdvantPlay Mini
			IF EXISTS (	SELECT TOP(1) 1 FROM @SportBettype
						WHERE Bettype = @BetType
							AND (ProductID IN (22, 24, 32, 34, 36, 42, 50, 55, 56, 60, 61, 62, 66, 67, 68)
								OR (ProductID = 6 AND SubProduct <> '')))
			BEGIN
				INSERT INTO @Data
				SELECT
					b.gameID AS BetType,
					b.transid,
					0 AS BetId,
					b.refno,
					CASE
						WHEN s.productID IN (24, 32, 34, 36) THEN b.Additional
						WHEN s.productID IN (42, 61, 62, 66, 67, 68) THEN ISNULL(b.SiteID, '')
						WHEN s.ProductID IN (55, 56) THEN b.GameId3rd
						ELSE ''
					END AS MatchCode,
					'' AS Race,
					CASE
						WHEN s.productID IN (60) THEN b.Transdate3rd
						ELSE ''
					END AS EventDate,
					0 AS virtualrate,
					0 AS isShowOTExRate,
					b.sdiscount,
					b.adiscount,
					b.discount,
					0 AS homeid,
					0 AS awayid,
					'' AS settleTime,
					0 AS hdp1,
					0 AS hdp2,
					CASE
						WHEN s.ProductID IN (6, 32, 42, 66) AND b.statusID IN (111, 112, 113) THEN ISNULL(b.ContributionRate, 0)
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
					CASE
						WHEN s.productID IN (61, 62, 67, 68) THEN b.GameId3rd
					ELSE ''
					END AS betteam,
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
					b.betfrom,
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
						WHEN s.ProductID IN (6, 32, 42, 66) AND b.statusID IN (111, 112, 113) THEN ISNULL(b.BetStake, 0)
						ELSE 0
					END AS OddsSpread,
					0 AS OriginalBetType,
					CASE
						WHEN s.ProductID IN (6, 32, 42, 66) THEN ISNULL(b.RefNo2, -1)
						ELSE -1
					END AS BetdaqId,
					CASE
						WHEN s.ProductID IN (6, 32, 42, 66) THEN ISNULL(b.JackpotInfo, '')
						ELSE ''
					END AS ExtraInfo,
					0 AS WalletType,
					0 AS RefCode
				FROM dbo.bettransRnG14 AS b WITH (NOLOCK)
					INNER JOIN @SportBettype AS s ON s.Bettype = b.gameID
				WHERE b.transid = @TransId
					AND (s.ProductId IN (22, 24, 32, 34, 36, 42, 50, 55, 56, 60, 61, 62, 66, 67, 68)
						OR (s.ProductId = 6 AND s.SubProduct <> ''))
			END
		END
	END

	-- BettransLC tables
	SET @WinLostDate = NULL
	SET @CustId = NULL

	-- bettransLC
	SELECT TOP(1)
		@TransId = b.transid,
		@BetType = b.gameID,
		@WinLostDate = b.winlostdate,
		@CustId = b.custid
	FROM dbo.bettransLC AS b WITH (NOLOCK)
		INNER JOIN @SportBettype AS sp ON b.gameID = sp.bettype
	WHERE b.transid = @RefNo

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
	BEGIN
		-- bettransLC
		IF @WinLostDate > @MoveBetsDay
		BEGIN
			-- AG Casino, AllBet, Sexy Gaming, IBCBet Live Casino, ION, WM, GDG, Big Gaming
			IF EXISTS ( SELECT TOP(1) 1 FROM @SportBettype WHERE ProductID IN (11, 21, 45, 46, 51, 52, 57, 59, 65) AND Bettype = @BetType )
			BEGIN
				INSERT INTO @Data
				SELECT
					b.gameID AS BetType,
					b.transid,
					0 AS BetId,
					b.refno,
					CASE
						WHEN s.ProductID IN (21, 45, 46, 51, 52, 57, 59, 65) THEN b.GameId3rd
						ELSE ''
					END AS matchcode,
					'' AS Race,
					'' AS eventdate,
					0 AS virtualrate,
					0 AS isShowOTExRate,
					b.sdiscount,
					b.adiscount,
					b.discount,
					0 AS homeid,
					0 AS awayid,
					'' AS settleTime,
					0 AS hdp1,
					0 AS hdp2,
					CASE
						WHEN s.ProductID IN (21, 45, 46, 51, 52, 57) THEN b.odds
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
					CASE
						WHEN s.ProductID IN (57, 59) THEN b.SiteID
						ELSE ''
					END AS betteam,
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
					CASE
						WHEN s.ProductID IN (57) THEN b.currency
						ELSE 0
					END AS leagueid,
					b.productID AS Sporttype,
					b.ip,
					b.betfrom,
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
					0 AS OddsSpread,
					0 AS OriginalBetType,
					-1 AS BetdaqId,
					'' AS ExtraInfo,
					0 AS WalletType,
					0 AS RefCode
				FROM dbo.bettransLC AS b WITH (NOLOCK)
					INNER JOIN @SportBettype AS s ON s.Bettype = b.gameID
				WHERE b.transid = @TransId
					AND s.ProductID IN (11, 21, 45, 46, 51, 52, 57, 59, 65)
			END
		END

		-- bettransLC14
		ELSE IF @WinLostDate BETWEEN @BalanceUpDay AND @MoveBetsDay
		BEGIN
			-- AG Casino, AllBet, Sexy Gaming, IBCBet Live Casino, ION, WM, GDG, Big Gaming, PP Live Casino
			IF EXISTS ( SELECT TOP(1) 1 FROM @SportBettype WHERE ProductID IN (11, 21, 45, 46, 51, 52, 57, 59, 65) AND Bettype = @BetType )
			BEGIN
				INSERT INTO @Data
				SELECT
					b.gameID AS BetType,
					b.transid,
					0 AS BetId,
					b.refno,
					CASE
						WHEN s.ProductID IN (21, 45, 46, 51, 52, 57, 59, 65) THEN b.GameId3rd
						ELSE ''
					END AS matchcode,
					'' AS Race,
					'' AS eventdate,
					0 AS virtualrate,
					0 AS isShowOTExRate,
					b.sdiscount,
					b.adiscount,
					b.discount,
					0 AS homeid,
					0 AS awayid,
					'' AS settleTime,
					0 AS hdp1,
					0 AS hdp2,
					CASE
						WHEN s.ProductID IN (21, 45, 46, 51, 52, 57) THEN b.odds
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
					CASE
						WHEN s.ProductID IN (57, 59) THEN b.SiteID
						ELSE ''
					END AS betteam,
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
					CASE
						WHEN s.ProductID IN (57) THEN b.currency
						ELSE 0
					END AS leagueid,
					b.productID AS Sporttype,
					b.ip,
					b.betfrom,
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
					0 AS OddsSpread,
					0 AS OriginalBetType,
					-1 AS BetdaqId,
					'' AS ExtraInfo,
					0 AS WalletType,
					0 AS RefCode
				FROM dbo.bettransLC14 AS b WITH (NOLOCK)
					INNER JOIN @SportBettype AS s ON s.Bettype = b.gameID
				WHERE b.transid = @TransId
					AND s.ProductID IN (11, 21, 45, 46, 51, 52, 57, 59, 65)
			END
		END
	END

	-- Get AllBet, Sexy Gaming, IBCBet Live Casino, ION, WM, GDG, Big Gaming, PP Live Casino related tickets (same game)
	IF @WinLostDate IS NOT NULL
		AND EXISTS (SELECT 1
					FROM @Data AS b
						INNER JOIN @SportBettype AS s ON s.Bettype = b.bettype
					WHERE s.ProductID IN (21, 45, 46, 51, 52, 57, 59, 65) AND b.MatchCode <> '')
	BEGIN
		IF @WinLostDate > @MoveBetsDay
		BEGIN
			INSERT INTO @Data
			SELECT
				b.gameID AS BetType,
				b.transid,
				0 AS BetId,
				b.refno,
				CASE
					WHEN s.ProductID IN (21, 45, 46, 51, 52, 57, 59, 65) THEN b.GameId3rd
					ELSE ''
				END AS matchcode,
				'' AS Race,
				'' AS eventdate,
				0 AS virtualrate,
				0 AS isShowOTExRate,
				b.sdiscount,
				b.adiscount,
				b.discount,
				0 AS homeid,
				0 AS awayid,
				'' AS settleTime,
				0 AS hdp1,
				0 AS hdp2,
				CASE
					WHEN s.ProductID IN (21, 45, 46, 51, 52, 57) THEN b.odds
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
				CASE
					WHEN s.ProductID IN (57, 59) THEN b.SiteID
					ELSE ''
				END AS betteam,
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
				CASE
					WHEN s.ProductID IN (57) THEN b.currency
					ELSE 0
				END AS leagueid,
				b.productID AS Sporttype,
				b.ip,
				b.betfrom,
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
				0 AS OddsSpread,
				0 AS OriginalBetType,
				-1 AS BetdaqId,
				'' AS ExtraInfo,
				0 AS WalletType,
				0 AS RefCode
			FROM dbo.bettransLC AS b WITH (NOLOCK)
				INNER JOIN @Data AS b1 ON b.custid = b1.CustId AND b.gameID = b1.BetType AND b.GameId3rd = b1.MatchCode
				INNER JOIN @SportBettype AS s ON s.Bettype = b1.bettype
			WHERE s.ProductID IN (21, 45, 46, 51, 52, 57, 59, 65)
				AND b1.MatchCode <> ''
				AND b.transid <> @TransId
		END

		-- bettransLC14
		ELSE IF @WinLostDate BETWEEN @BalanceUpDay AND @MoveBetsDay
		BEGIN
			INSERT INTO @Data
			SELECT
				b.gameID AS BetType,
				b.transid,
				0 AS BetId,
				b.refno,
				CASE
					WHEN s.ProductID IN (21, 45, 46, 51, 52, 57, 59, 65) THEN b.GameId3rd
					ELSE ''
				END AS matchcode,
				'' AS Race,
				'' AS eventdate,
				0 AS virtualrate,
				0 AS isShowOTExRate,
				b.sdiscount,
				b.adiscount,
				b.discount,
				0 AS homeid,
				0 AS awayid,
				'' AS settleTime,
				0 AS hdp1,
				0 AS hdp2,
				CASE
					WHEN s.ProductID IN (21, 45, 46, 51, 52, 57) THEN b.odds
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
				CASE
					WHEN s.ProductID IN (57, 59) THEN b.SiteID
					ELSE ''
				END AS betteam,
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
				CASE
					WHEN s.ProductID IN (57) THEN b.currency
					ELSE 0
				END AS leagueid,
				b.productID AS Sporttype,
				b.ip,
				b.betfrom,
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
				0 AS OddsSpread,
				0 AS OriginalBetType,
				-1 AS BetdaqId,
				'' AS ExtraInfo,
				0 AS WalletType,
				0 AS RefCode
			FROM dbo.bettransLC14 AS b WITH (NOLOCK)
				INNER JOIN @Data AS b1 ON b.custid = b1.CustId AND b.gameID = b1.BetType AND b.GameId3rd = b1.MatchCode
				INNER JOIN @SportBettype AS s ON s.Bettype = b1.bettype
			WHERE s.ProductID IN (21, 45, 46, 51, 52, 57, 59, 65)
				AND b1.MatchCode <> ''
				AND b.transid <> @TransId
		END
	END

	-- Bettransg tables
	SET @WinLostDate = NULL
	SET @CustId = NULL

	-- bettransg
	SELECT TOP(1)
		@TransId = b.transid,
		@BetType = b.bettype,
		@WinLostDate = b.winlostdate,
		@CustId = b.custid
	FROM dbo.bettransg AS b WITH (NOLOCK)
		INNER JOIN @SportBettype AS sp ON b.bettype = sp.bettype
	WHERE b.transid = @RefNo

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
	BEGIN
		-- bettransg
		IF @WinLostDate > @MoveBetsDay
		BEGIN
			-- SA Gaming, BBIN
			IF EXISTS ( SELECT TOP(1) 1 FROM @SportBettype WHERE ProductID IN (39, 47) AND Bettype = @BetType )
			BEGIN
				INSERT INTO @Data
				SELECT
					b.bettype,
					b.transid,
					0 AS BetId,
					b.refno,
					CASE
						WHEN s.ProductID = 39 THEN ISNULL(blc.GameId3rd, '')
						ELSE ''
					END AS matchcode,
					'' AS Race,
					'' AS eventdate,
					0 AS virtualrate,
					0 AS isShowOTExRate,
					b.sdiscount,
					b.adiscount,
					b.discount,
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
					CASE
						WHEN s.ProductID = 39 THEN ISNULL(b.BetID3rd, '')
						WHEN s.ProductID = 47 THEN ISNULL(b.betteam, '')
						ELSE ''
					END AS BetTeam,
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
					CASE
						WHEN s.ProductID = 39 THEN ISNULL(blc.ProductID, 0)
						ELSE b.matchid
					END AS Sporttype,
					CASE
						WHEN s.ProductID = 39 THEN ISNULL(blc.ip, '')
						ELSE ISNULL(b2.ip, '')
					END AS Ip,
					b.betfrom,
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
					CASE
						WHEN s.ProductID = 39 THEN ISNULL(b.TransDesc, '')
						ELSE ISNULL(b.BetID3rd, '')
					END AS BetCheck,
					CASE
						WHEN s.ProductID = 39 THEN ISNULL(blc.transdesc, '')
						ELSE ISNULL(b.transdesc, '')
					END AS TransDesc,
					0 AS OddsSpread,
					0 AS OriginalBetType,
					-1 AS BetdaqId,
					'' AS ExtraInfo,
					0 AS WalletType,
					0 AS RefCode
				FROM dbo.bettransg AS b WITH (NOLOCK)
					INNER JOIN @SportBettype AS s ON s.BetType = b.bettype
					LEFT JOIN dbo.bettransLC AS blc WITH (NOLOCK) ON b.refno = blc.transid AND b.custid = blc.custid
					LEFT JOIN dbo.bettrans AS b2 WITH (NOLOCK) ON b2.transid = b.refno AND b2.custid = b.CustId
				WHERE b.transid = @TransId AND s.ProductID IN (39, 47)
			END
		END

		-- bettransg14
		ELSE IF @WinLostDate BETWEEN @BalanceUpDay AND @MoveBetsDay
		BEGIN
			-- SA Gaming, BBIN
			IF EXISTS ( SELECT TOP(1) 1 FROM @SportBettype WHERE ProductID IN (39, 47) AND Bettype = @BetType )
			BEGIN
				INSERT INTO @Data
				SELECT
					b.bettype,
					b.transid,
					0 AS BetId,
					b.refno,
					CASE
						WHEN s.ProductID = 39 THEN ISNULL(blc.GameId3rd, '')
						ELSE ''
					END AS matchcode,
					'' AS Race,
					'' AS eventdate,
					0 AS virtualrate,
					0 AS isShowOTExRate,
					b.sdiscount,
					b.adiscount,
					b.discount,
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
					CASE
						WHEN s.ProductID = 39 THEN ISNULL(b.BetID3rd, '')
						WHEN s.ProductID = 47 THEN ISNULL(b.betteam, '')
						ELSE ''
					END AS BetTeam,
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
					CASE
						WHEN s.ProductID = 39 THEN ISNULL(blc.ProductID, 0)
						ELSE b.matchid
					END AS Sporttype,
					CASE
						WHEN s.ProductID = 39 THEN ISNULL(blc.ip, '')
						ELSE ISNULL(b2.ip, '')
					END AS Ip,
					b.betfrom,
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
					CASE
						WHEN s.ProductID = 39 THEN ISNULL(b.TransDesc, '')
						ELSE ISNULL(b.BetID3rd, '')
					END AS BetCheck,
					CASE
						WHEN s.ProductID = 39 THEN ISNULL(blc.transdesc, '')
						ELSE ISNULL(b.transdesc, '')
					END AS TransDesc,
					0 AS OddsSpread,
					0 AS OriginalBetType,
					-1 AS BetdaqId,
					'' AS ExtraInfo,
					0 AS WalletType,
					0 AS RefCode
				FROM dbo.bettransg14 AS b WITH (NOLOCK)
					INNER JOIN @SportBettype AS s ON s.Bettype = b.Bettype
					LEFT JOIN dbo.bettransLC AS blc WITH (NOLOCK) ON b.refno = blc.transid AND b.custid = blc.custid
					LEFT JOIN dbo.bettrans14 AS b2 WITH (NOLOCK) ON b2.transid = b.refno AND b2.custid = b.CustId
				WHERE b.transid = @TransId AND s.ProductID IN (39, 47)
			END
		END

		-- bettransg bk
		ELSE
		BEGIN
			-- SA Gaming, BBIN
			IF EXISTS ( SELECT TOP(1) 1 FROM @SportBettype WHERE ProductID IN (39, 47) AND Bettype = @BetType )
			BEGIN
				INSERT INTO @Data
				SELECT
					b.bettype,
					b.transid,
					0 AS BetId,
					b.refno,
					CASE
						WHEN s.ProductID = 39 THEN ISNULL(blc.GameId3rd, '')
						ELSE ''
					END AS matchcode,
					'' AS Race,
					'' AS eventdate,
					0 AS virtualrate,
					0 AS isShowOTExRate,
					b.sdiscount,
					b.adiscount,
					b.discount,
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
					CASE
						WHEN s.ProductID = 39 THEN ISNULL(b.BetID3rd, '')
						WHEN s.ProductID = 47 THEN ISNULL(b.betteam, '')
						ELSE ''
					END AS BetTeam,
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
					CASE
						WHEN s.ProductID = 39 THEN ISNULL(blc.ProductID, 0)
						ELSE b.matchid
					END AS Sporttype,
					CASE
						WHEN s.ProductID = 39 THEN ISNULL(dp.ip, '')
						ELSE ISNULL(dp2.ip, '')
					END AS Ip,
					b.betfrom,
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
					CASE
						WHEN s.ProductID = 39 THEN ISNULL(b.TransDesc, '')
						ELSE ISNULL(b.BetID3rd, '')
					END AS BetCheck,
					CASE
						WHEN s.ProductID = 39 THEN ISNULL(blc.transdesc, '')
						ELSE ISNULL(b.transdesc, '')
					END AS TransDesc,
					0 AS OddsSpread,
					0 AS OriginalBetType,
					-1 AS BetdaqId,
					'' AS ExtraInfo,
					0 AS WalletType,
					0 AS RefCode
				FROM bodb_Archive.dbo.bettransg AS b WITH (NOLOCK)
					INNER JOIN @SportBettype AS s ON s.Bettype = b.Bettype
					LEFT JOIN bodb_Archive.dbo.bettransLC_bk AS blc WITH (NOLOCK) ON b.refno = blc.transid AND b.custid = blc.custid
					CROSS APPLY bodb02.dbo.f_IP_Decompress(blc.Ip) AS dp
					LEFT JOIN bodb_Archive.dbo.bettrans_bk AS b2 WITH (NOLOCK) ON b2.transid = b.refno AND b2.custid = b.CustId
					CROSS APPLY bodb02.dbo.f_IP_Decompress(b2.Ip) AS dp2
				WHERE b.transid = @TransId AND s.ProductID IN (39, 47)
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
			INSERT INTO @Data
			SELECT
				b.bettype,
				b.transid,
				0 AS BetId,
				b.refno,
				CASE
					WHEN s.ProductID = 39 THEN ISNULL(blc.GameId3rd, '')
					ELSE ''
				END AS matchcode,
				'' AS Race,
				'' AS eventdate,
				0 AS virtualrate,
				0 AS isShowOTExRate,
				b.sdiscount,
				b.adiscount,
				b.discount,
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
				CASE
					WHEN s.ProductID = 39 THEN ISNULL(b.BetID3rd, '')
					WHEN s.ProductID = 47 THEN ISNULL(b.betteam, '')
					ELSE ''
				END AS BetTeam,
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
				CASE
					WHEN s.ProductID = 39 THEN ISNULL(blc.ProductID, 0)
					ELSE b.matchid
				END AS Sporttype,
				CASE
					WHEN s.ProductID = 39 THEN ISNULL(blc.ip, '')
					ELSE ISNULL(b2.ip, '')
				END AS Ip,
				b.betfrom,
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
				CASE
					WHEN s.ProductID = 39 THEN ISNULL(b.TransDesc, '')
					ELSE ISNULL(b.BetID3rd, '')
				END AS BetCheck,
				CASE
					WHEN s.ProductID = 39 THEN ISNULL(blc.transdesc, '')
					ELSE ISNULL(b.transdesc, '')
				END AS TransDesc,
				0 AS OddsSpread,
				0 AS OriginalBetType,
				-1 AS BetdaqId,
				'' AS ExtraInfo,
				0 AS WalletType,
				0 AS RefCode
			FROM dbo.bettransg AS b WITH (NOLOCK)
				INNER JOIN @Data AS b1 ON b.custid = b1.CustId AND b.bettype = b1.BetType AND b.winlostdate = b1.WinLostDate
				INNER JOIN @SportBettype AS s ON s.Bettype = b1.bettype
				LEFT JOIN dbo.bettransLC AS blc WITH (NOLOCK) ON b.refno = blc.transid AND b.custid = blc.custid
				LEFT JOIN dbo.bettrans AS b2 WITH (NOLOCK) ON b2.transid = b.refno AND b2.custid = b.CustId
			WHERE b.transid <> @TransId
				AND ((s.productID = 39
						AND b1.MatchCode <> ''
						AND b.betteam = b1.MatchCode)
					OR (s.productID = 47
						AND b1.BetTeam <> ''
						AND b.betteam = b1.BetTeam))
		END

		-- bettransg14
		ELSE IF @WinLostDate BETWEEN @BalanceUpDay AND @MoveBetsDay
		BEGIN
			INSERT INTO @Data
			SELECT
				b.bettype,
				b.transid,
				0 AS BetId,
				b.refno,
				CASE
					WHEN s.ProductID = 39 THEN ISNULL(blc.GameId3rd, '')
					ELSE ''
				END AS matchcode,
				'' AS Race,
				'' AS eventdate,
				0 AS virtualrate,
				0 AS isShowOTExRate,
				b.sdiscount,
				b.adiscount,
				b.discount,
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
				CASE
					WHEN s.ProductID = 39 THEN ISNULL(b.BetID3rd, '')
					WHEN s.ProductID = 47 THEN ISNULL(b.betteam, '')
					ELSE ''
				END AS BetTeam,
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
				CASE
					WHEN s.ProductID = 39 THEN ISNULL(blc.ProductID, 0)
					ELSE b.matchid
				END AS Sporttype,
				CASE
					WHEN s.ProductID = 39 THEN ISNULL(blc.ip, '')
					ELSE ISNULL(b2.ip, '')
				END AS Ip,
				b.betfrom,
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
				CASE
					WHEN s.ProductID = 39 THEN ISNULL(b.TransDesc, '')
					ELSE ISNULL(b.BetID3rd, '')
				END AS BetCheck,
				CASE
					WHEN s.ProductID = 39 THEN ISNULL(blc.transdesc, '')
					ELSE ISNULL(b.transdesc, '')
				END AS TransDesc,
				0 AS OddsSpread,
				0 AS OriginalBetType,
				-1 AS BetdaqId,
				'' AS ExtraInfo,
				0 AS WalletType,
				0 AS RefCode
			FROM dbo.bettransg14 AS b WITH (NOLOCK)
				INNER JOIN @Data AS b1 ON b.custid = b1.CustId AND b.bettype = b1.BetType AND b.winlostdate = b1.WinLostDate
				INNER JOIN @SportBettype AS s ON s.Bettype = b1.bettype
				LEFT JOIN dbo.bettransLC14 AS blc WITH (NOLOCK) ON b.refno = blc.transid AND b.custid = blc.custid
				LEFT JOIN dbo.bettrans14 AS b2 WITH (NOLOCK) ON b2.transid = b.refno AND b2.custid = b.CustId
			WHERE b.transid <> @TransId
				AND ((s.productID = 39
						AND b1.MatchCode <> ''
						AND b.betteam = b1.MatchCode)
					OR (s.productID = 47
						AND b1.BetTeam <> ''
						AND b.betteam = b1.BetTeam))
		END

		-- bettransg bk
		ELSE
		BEGIN
			INSERT INTO @Data
			SELECT
				b.bettype,
				b.transid,
				0 AS BetId,
				b.refno,
				CASE
					WHEN s.ProductID = 39 THEN ISNULL(blc.GameId3rd, '')
					ELSE ''
				END AS matchcode,
				'' AS Race,
				'' AS eventdate,
				0 AS virtualrate,
				0 AS isShowOTExRate,
				b.sdiscount,
				b.adiscount,
				b.discount,
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
				CASE
					WHEN s.ProductID = 39 THEN ISNULL(b.BetID3rd, '')
					WHEN s.ProductID = 47 THEN ISNULL(b.betteam, '')
					ELSE ''
				END AS BetTeam,
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
				CASE
					WHEN s.ProductID = 39 THEN ISNULL(blc.ProductID, 0)
					ELSE b.matchid
				END AS Sporttype,
				CASE
					WHEN s.ProductID = 39 THEN ISNULL(dp.ip, '')
					ELSE ISNULL(dp2.ip, '')
				END AS Ip,
				b.betfrom,
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
				CASE
					WHEN s.ProductID = 39 THEN ISNULL(b.TransDesc, '')
					ELSE ISNULL(b.BetID3rd, '')
				END AS BetCheck,
				CASE
					WHEN s.ProductID = 39 THEN ISNULL(blc.transdesc, '')
					ELSE ISNULL(b.transdesc, '')
				END AS TransDesc,
				0 AS OddsSpread,
				0 AS OriginalBetType,
				-1 AS BetdaqId,
				'' AS ExtraInfo,
				0 AS WalletType,
				0 AS RefCode
			FROM bodb_Archive.dbo.bettransg AS b WITH (NOLOCK)
				INNER JOIN @Data AS b1 ON b.custid = b1.CustId AND b.bettype = b1.bettype AND b.winlostdate = b1.WinLostDate
				INNER JOIN @SportBettype AS s ON s.Bettype = b1.bettype
				LEFT JOIN bodb_Archive.dbo.bettransLC_bk AS blc WITH (NOLOCK) ON b.refno = blc.transid AND b.custid = blc.custid
				CROSS APPLY bodb02.dbo.f_IP_Decompress(blc.Ip) AS dp
				LEFT JOIN bodb_Archive.dbo.bettrans_bk AS b2 WITH (NOLOCK) ON b2.transid = b.refno AND b2.custid = b.CustId
				CROSS APPLY bodb02.dbo.f_IP_Decompress(b2.Ip) AS dp2
			WHERE b.transid <> @TransId
				AND ((s.productID = 39
						AND b1.MatchCode <> ''
						AND b.betteam = b1.MatchCode)
					OR (s.productID = 47
						AND b1.BetTeam <> ''
						AND b.betteam = b1.BetTeam))
		END
	END

	SELECT b.*,
		ci.username,
		ex.currency
	FROM @Data AS b
		LEFT JOIN dbo.custInfo AS ci WITH (NOLOCK) ON b.CustId = ci.custid
		LEFT JOIN dbo.Exchange AS ex WITH (NOLOCK) ON ci.currency = ex.exchangeid
	ORDER BY b.TransId ASC

	SELECT * FROM @DetailData
END
GO
