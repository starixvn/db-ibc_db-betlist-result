/*<info serverAlias="DBACC-bodb02" executers="wsv_nap" viewers="" isFunction="0" isNested="0"></info>*/

ALTER PROCEDURE [dbo].[Acc_BetListByIP_OtherSports]
	@CustId			INT,
	@Ip				VARCHAR(45),
	@FromDate		SMALLDATETIME,
	@MoveBetsDay	SMALLDATETIME,
	@BalanceUpDay	SMALLDATETIME
AS

/*
	Created: Phuong Dao
	Task: Bet List By IP and Other Sports
	DB: DBACC.bodb02

	Revisions:
		- 20090509@Simon: Bet List For Casino
		- 20090528@PhuongDao: Add HR Fixed Odd
		- 20091002@Simon: Get Odds && OddsType columns
		- 20091003@Jamie: Remove comstatus out
		- 20091009@Daniel: Get refund status from bettrans
		- 20091015@Shifu: Get refno
		- 20091023@Simon: Displays Odds at Bet/Settle time
		- 20091205@Henry: Get more column: refno for viewing Mix Parlay detail
		- 20100524@Jamie: Show currency2's exchange rate for OpenTote
		- 20100611@Henry: Change mix-parlay match from 0 to 9
		- 20100907@Henry: Add IBC Bingo bettype
		- 20101130@Henry: Add column betid for number game
		- 20101201@Henry: Return winlost-actual_stake for column winlost
		- 20110408@Amy: Change function to get Odds value and odds type
		- 20110516@Lukas: re-arrange bettype
		- 20110711@Johnson: show exchange rate for SA Tote
		- 20110802@Johnson: Add new bettype combination mix-parlay
						- Add new column actual_stake into betlist
		- 20111122@Sophia: Add Checktime and SecAcceptFlag to show status waiting or running
		- 20111207@Sophia: Add P2P
		- 20120120@Sophia: Add Showtime for Table-hand-shoe of Live Casino
						- Add sub detail for Live Casino
		- 20120321@Sophia: Select @Data table (fix bug)
		- 20120405@Hurri: Exclude bettype 72 (P2P bet ticket) in the calculation of Casino
		- 20120410@Hurri: change matchid 0 -> 1000 for bettype 1000
		- 20120417@Johnson: Correct column transid for p2p
		- 20120423@Lukas: show transid of main ticket for all subticket of system parlay
		- 20120606@Sophia: Change datatype of stake to money
		- 20120626@Elodie: exclude outright, HR from sportbook ( in case of matchid = orid)
		- 20120629@Sophia: Remove function f_GetOddsByBettype, f_ShowOddsByBettype for odds, Oddstype
		- 20120927@Johnson: get commstatus column to check double comm losing
		- 20121029@Elodie: Get matchid column
		- 20130227@Elodie: Add Virtual HR product
		- 20130625@Elodie: Not apply Virtual HR for bet list by IP yet at this time
		- 20130703@Kathy: Update matchid for RnG Casino(71) and Bingo(73)
		- 20130718@Elodie: Apply core betlist
		- 20131126@Lukas: get sporttype column in VSRaceinfo instead of hardcode
		- 20140306@Dom: Add Keno
		- 20140908@Dom: Update VS conditions [Redmine #22012]
		- 20141103@Dom: Apply sport bettype matrix
		- 20150506@Tom: Support Gold Deluxe Product [#34847]
		- 20150506@Bobby: Add transdesc column for metric gaming bettypes (801-899)
		- 20150709@Edward: Supporting for Microgaming
		- 20150826@Kos: Add OddsSpread column to support Myanmar Odds
		- 20150831@Kos: Support Colossus Bet
		- 20151009@Kos: Support Microgaming RNG Casino and AG casino
		- 20151023@Kos: Return [translog].[transid3rd] and [bettransm].[betcheck] to support view CB ticket detail
		- 20151030@Kos: Change ProductId/SportType of Microgaming RNG Casino
		- 20151210@Kos: Change odds, modds data type from SMALLMONEY to MONEY [Redmine: #48660]
		- 20151216@Kos: Support Cockfighting (#Redmine: 48850)
		- 20151231@Kos: Support RNG Casino Single Wallet [Redmine: #48958]
		- 20160121@Kos: Support PH All In One 1.2 [#Redmine: 50897]
		- 20160125@Kos: Fix Colossus Bet result issue
		- 20160129@Kos: Support RNG Casino Single Wallet yesterday running ticket
		- 20160215@Kos: Support AllBet [#Redmine: 50864]
		- 20160331@Kos: Support Voidbridge [#Redmine: 54925]
		- 20160407@Kos: Support Combo Parlay [#Redmine: 55282]
		- 20160711@Kos: Change to use inline function for SportBettypeMatrix
		- 20160801@Kos: Fix bug not showing summary tickets if have only Void/Reject detail tickets [#Redmine: 61651]
		- 20160810@Kos: Support NG2
		- 20161019@Kos: Remove Bingo and P2P in bettrans and bettrans14 range [#Redmine: 53988]
					- Support Fishing World [#Redmine: 65934]
		- 20170228@Kos: Support KickOffTime for Virtual Soccer and Virtual Tennis [#Redmine: 71906]
		- 20170321@Kos: Support CashOut [#Redmine: 71963]
		- 20170620@Kos: Support Betradar Virtual Sports [#Redmine: 77280]
		- 20170629@Kos: Support Keno Lottery [#Redmine: 77929]
		- 20170718@Kos: Don't parse transdesc for Keno anymore [#Redmine: 80082]
		- 20170829@Kos: Support Lucky 3 [#Redmine: 75277]
		- 20171025@Kos: Support Bullfighting [#Redmine: 84961]
					- Don't support Live Casino anymore
		- 20171227@Kos: Return ticket detail of Racing and Virtual Horse Racing [#Redmine: 88775]
					- Don't support Live Casino in bettrans and bettrans14 anymore
		- 20180118@Kos: Support Licensee Bonus System [#Redmine: 74978]
		- 20180305@Kos: Don't support Racing, Cockfighting, RNG Casino (bettype 71, 72) anymore [#Redmine: 86086]
		- 20180323@Kos: Support ONERnG Jackpot [#Redmine: 88652]
		- 20180405@Kos: Support Pragmatic Casino [#Redmine: 92160]
		- 20180510@Kos: Support Keno 6 new Mini Games [#Redmine: 93759]
		- 20180515@Kos: Add Match No for Bullfighting [#Redmine: 84961]
		- 20180709@Kos: Support Poker Games [#Redmine: 97565]
		- 20180911@Kos: Hotfix - Wrong operator name [#Redmine: 101299]
		- 20180927@Kos: Support new status Result Pending and Under Settlement [#Redmine: 101949]
		- 20181218@Kos: Support E-Sports phase 2b [#Redmine: 106456]
		- 20190107@Kos: Support Parlay Changes [#Redmine: 105585]
		- 20190321@Kos: Support Pragmatic Promotion Prize [#Redmine: 108117]
		- 20190503@Kos: Show match KO time for single ticket [#Redmine: 112092]
		- 20190611@Kos: Support Card Club [#Redmine: 107645]
					- Don't support Poker Games anymore
		- 20190722@Kos: Support new status Pending [#Redmine: 113142]
		- 20190827@Kos: Support bk range [Redmine: #119018]
					- Don't support Microgaming Live Casino, Microgaming RNG Casino, Lucky 3, Poker Games anymore [Redmine: #119018]
					- Add new params @MoveBetsDay and @BalanceUpDay
		- 20191029@Kos: Show Running status for Marked tickets [Redmine: 122391]
		- 20191105@Kos: Support Non-peak Hours Promotion [#Redmine: 121121]
		- 20191127@Kos: Hotfix - Change oddsspread data type from SMALLMONEY to MONEY [Redmine: #124483]
		- 20191128@Kos: Support Spadegaming [Redmine: #122140]
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
		- 20210914@Razor: Support Cashout for Basketball [Redmine: #159617]
		- 20211004@Razor: Extend Data type of IP v6 [Redmine: #90903]
		- 20211004@Razor: Extend Data type of IP v6 - times 2 [Redmine: #90903]
		- 20211025@Razor: Decompress IP on BK range [Redmine: #90903]
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
		- 20230727@Razor: Support Virtual Sports 3 [Redmine: #189205]
		- 20230909@Razor: Remove GDG, Fishing World products [Redmine: #174511]
		- 20230909@Razor: Remove GD, Colossusbet products [Redmine: #179132]
		- 20231005@Kos: Support Parlay Boost [Redmine: #194992]
					- Don't support Cash Out bettype 911, 912, 913 in range bettrans and bettrans14 anymore
		- 20231020@Razor: Support show max payout [Redmine: #194491]
		- 20231027@Razor: Support new bettype of Virtual Sport 3 (LG) [Redmine: #194634]
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
		- 20240717@Razor: Support FA CHAI [Redmine: #206633]
		- 20240806@Razor: Support Nextspin [Redmine: #199985]
*/

BEGIN
	SET NOCOUNT ON

	DECLARE @Data TABLE (
		TransId				BIGINT,
		RefNo				BIGINT,
		CustId				INT,
		Creator				INT,
		Currency			SMALLINT,
		SportType			SMALLINT,
		BetType				SMALLINT,
		BetId				BIGINT,
		BetTeam				NVARCHAR(20),
		Hdp1				SMALLMONEY,
		Hdp2				SMALLMONEY,
		OddsId				INT,
		OddsType			TINYINT,
		Odds				MONEY,
		MOdds				MONEY,
		OddsSpread			MONEY,
		Stake				MONEY,
		Actual_Stake		MONEY,
		WinLost				MONEY,
		Commission			MONEY,
		Status				NVARCHAR(10),
		SettlementStatus	TINYINT,
		SecAcceptFlag		BIT,
		CheckTime			DATETIME,
		TransDate			DATETIME,
		WinLostDate			SMALLDATETIME,
		LiveIndicator		BIT,
		LiveHomeScore		SMALLINT,
		LiveAwayScore		SMALLINT,
		Ip					VARCHAR(45),
		LeagueId			INT,
		MatchId				INT,
		MatchCode			NVARCHAR(50),
		Race				NVARCHAR(50),
		EventDate			DATETIME,
		HomeId				INT,
		AwayId				INT,
		IsNeutral			BIT,
		ShowTime			NVARCHAR(50),
		BetCheck			NVARCHAR(50),
		ComStatus			NVARCHAR(20),
		TransDesc			NVARCHAR(1000),
		BetdaqId			BIGINT,
		ExtraInfo			VARCHAR(1000),
		OriginalBetType		SMALLINT,
		WalletType			TINYINT,
		RefCode				BIGINT,
		ProductId			INT,
		EventId				INT,
		Custom1				NVARCHAR(50),
		Custom2				NVARCHAR(50),
		Custom3				NVARCHAR(50),
		Gameid3rd			NVARCHAR(50),
		Tranid3rd			NVARCHAR(200),
		TableID				TINYINT,
		Product				VARCHAR(30),
		CurrencyId			TINYINT,
		SiteId				VARCHAR(20),
		DeviceType			TINYINT,
		RefTable			TINYINT
	)

	-- Get ticket detail
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

	DECLARE @TmpData TABLE (
		RefNo			BIGINT,
		Odds			MONEY,
		Stake			MONEY,
		Actual_Stake	MONEY,
		Status			NVARCHAR(10),
		WinLost			MONEY,
		Commission		MONEY,
		OddsSpread		MONEY
	)

	DECLARE @Date DATETIME

	SET @Date = @FromDate

	DECLARE @CompressedIp VARCHAR(16)
	DECLARE @DeCompressedIp VARCHAR(45)

	-- bettrans range
	IF @Date > @MoveBetsDay
	BEGIN
		-- bettrans
		INSERT INTO @Data (
			TransId,
			RefNo,
			CustId,
			Creator,
			Currency,
			BetType,
			BetId,
			BetTeam,
			Hdp1,
			Hdp2,
			OddsId,
			OddsType,
			Odds,
			MOdds,
			OddsSpread,
			Stake,
			Actual_Stake,
			WinLost,
			Commission,
			Status,
			SecAcceptFlag,
			CheckTime,
			TransDate,
			WinLostDate,
			LiveIndicator,
			LiveHomeScore,
			LiveAwayScore,
			Ip,
			MatchId,
			BetCheck,
			ComStatus,
			TransDesc,
			BetdaqId,
			ExtraInfo,
			WalletType,
			RefCode,
			TableID,
			CurrencyId,
			SiteId,
			DeviceType)
		SELECT
			b.transid,
			b.refno,
			b.custid,
			b.creator,
			b.currency,
			b.bettype,
			ISNULL(b.betid, 0) AS BetId,
			b.betteam,
			b.hdp1,
			b.hdp2,
			b.oddsid,
			b.oddstype,
			b.odds,
			b.modds,
			b.oddsspread,
			b.stake,
			b.actual_stake,
			b.winlost,
			b.playercomm,
			b.status,
			b.SecAcceptFlag,
			b.checktime,
			b.transdate,
			b.winlostdate,
			b.liveindicator,
			b.livehomescore,
			b.liveawayscore,
			b.ip,
			b.matchid,
			b.betcheck,
			b.comstatus,
			b.transdesc,
			b.betdaqid,
			b.ExtraInfo,
			b.WalletType,
			ISNULL(b.RefCode, 0),
			1 AS TableID,
			b.currency,
			b.betdaqid,
			b.DeviceType
		FROM dbo.bettrans AS b WITH (NOLOCK)
		WHERE b.custid = @CustId
			AND b.winlostdate = @Date
			AND b.ip = @Ip

		-- translog
		INSERT INTO @Data (
			TransId,
			RefNo,
			CustId,
			Creator,
			Currency,
			BetType,
			Odds,
			Stake,
			Actual_Stake,
			Status,
			TransDate,
			WinLostDate,
			LiveIndicator,
			Ip,
			TransDesc,
			ProductId,
			EventId,
			Custom1,
			Custom2,
			Custom3,
			Gameid3rd,
			Tranid3rd,
			TableID,
			CurrencyId,
			SiteId,
			DeviceType
		)
		SELECT
			b.translogid AS TransId,
			b.translogid AS RefNo,
			b.custid,
			b.creator,
			b.currency,
			b.gameID AS BetType,
			b.odds,
			b.stake,
			b.actual_stake,
			b.status,
			b.transdate,
			b.transdate AS WinLostDate,
			b.LiveIndicator,
			b.ip,
			b.transdesc,
			b.productID,
			b.eventID,
			b.custom1,
			b.custom2,
			b.custom3,
			b.GameId3rd,
			b.TranId3rd,
			4 AS TableID,
			b.currency,
			b.SiteId,
			b.DeviceType
		FROM dbo.translog AS b WITH (NOLOCK)
		WHERE b.custid = @CustId
			AND b.winlostdate = @Date
			AND b.ip = @Ip
			AND b.statusID IN (0, 1)
			AND b.gameID NOT BETWEEN 801 AND 806
	END
	ELSE IF @Date BETWEEN @BalanceUpDay AND @MoveBetsDay		-- bettrans14 range
	BEGIN
		-- bettrans14
		INSERT INTO @Data (
			TransId,
			RefNo,
			CustId,
			Creator,
			Currency,
			BetType,
			BetId,
			BetTeam,
			Hdp1,
			Hdp2,
			OddsId,
			OddsType,
			Odds,
			MOdds,
			OddsSpread,
			Stake,
			Actual_Stake,
			WinLost,
			Commission,
			Status,
			SecAcceptFlag,
			CheckTime,
			TransDate,
			WinLostDate,
			LiveIndicator,
			LiveHomeScore,
			LiveAwayScore,
			Ip,
			MatchId,
			BetCheck,
			ComStatus,
			TransDesc,
			BetdaqId,
			ExtraInfo,
			WalletType,
			RefCode,
			TableID,
			CurrencyId,
			SiteId,
			DeviceType)
		SELECT
			b.transid,
			b.refno,
			b.custid,
			b.creator,
			b.currency,
			b.bettype,
			ISNULL(b.betid, 0) AS BetId,
			b.betteam,
			b.hdp1,
			b.hdp2,
			b.oddsid,
			b.oddstype,
			b.odds,
			b.modds,
			b.oddsspread,
			b.stake,
			b.actual_stake,
			b.winlost,
			b.playercomm,
			b.status,
			b.SecAcceptFlag,
			b.checktime,
			b.transdate,
			b.winlostdate,
			b.liveindicator,
			b.livehomescore,
			b.liveawayscore,
			b.ip,
			b.matchid,
			b.betcheck,
			b.comstatus,
			b.transdesc,
			b.betdaqid,
			b.ExtraInfo,
			b.WalletType,
			ISNULL(b.RefCode, 0),
			2 AS TableID,
			b.currency,
			b.betdaqid,
			b.DeviceType
		FROM dbo.bettrans14 AS b WITH (NOLOCK)
		WHERE b.custid = @CustId
			AND b.winlostdate = @Date
			AND b.ip = @Ip
	END
	ELSE IF @Date < @BalanceUpDay		-- bettrans_bk range
	BEGIN
		SELECT @CompressedIp = Ip FROM dbo.f_IP_Compress(@Ip)
		SELECT @DeCompressedIp = Ip FROM dbo.f_IP_Decompress(@CompressedIp)

		-- bettrans_bk
		INSERT INTO @Data (
			TransId,
			RefNo,
			CustId,
			Creator,
			Currency,
			BetType,
			BetId,
			BetTeam,
			Hdp1,
			Hdp2,
			OddsId,
			OddsType,
			Odds,
			MOdds,
			OddsSpread,
			Stake,
			Actual_Stake,
			WinLost,
			Commission,
			Status,
			SecAcceptFlag,
			CheckTime,
			TransDate,
			WinLostDate,
			LiveIndicator,
			LiveHomeScore,
			LiveAwayScore,
			Ip,
			MatchId,
			BetCheck,
			ComStatus,
			TransDesc,
			BetdaqId,
			ExtraInfo,
			WalletType,
			RefCode,
			TableID,
			CurrencyId,
			SiteId,
			DeviceType)
		SELECT
			b.transid,
			b.refno,
			b.custid,
			b.creator,
			b.currency,
			b.bettype,
			ISNULL(b.betid, 0) AS BetId,
			b.betteam,
			b.hdp1,
			b.hdp2,
			b.oddsid,
			b.oddstype,
			b.odds,
			b.modds,
			b.oddsspread,
			b.stake,
			b.actual_stake,
			b.winlost,
			b.playercomm,
			b.status,
			b.SecAcceptFlag,
			b.checktime,
			b.transdate,
			b.winlostdate,
			b.liveindicator,
			b.livehomescore,
			b.liveawayscore,
			b.ip,
			b.matchid,
			b.betcheck,
			b.comstatus,
			b.transdesc,
			b.betdaqid,
			b.ExtraInfo,
			b.WalletType,
			ISNULL(b.RefCode, 0),
			3 AS TableID,
			b.currency,
			b.betdaqid,
			b.DeviceType
		FROM bodb_Archive.dbo.bettrans_bk AS b WITH (NOLOCK, INDEX = IX_custid)
		CROSS APPLY dbo.f_IP_Decompress(b.ip) AS dp
		WHERE b.custid = @CustId
			AND b.winlostdate = @Date
			AND dp.Ip = @DeCompressedIp
			
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
				b.Stake = cob.stake
			FROM @Data AS b
				INNER JOIN bodb_Archive.dbo.bettrans_bk AS cob WITH (NOLOCK) ON b.RefNo = cob.transid
				INNER JOIN bodb_Archive.dbo.bettrans_bk AS ob WITH (NOLOCK) ON cob.RefNo = ob.transid
				LEFT JOIN @Data AS cb
					ON cb.RefNo = b.RefNo
					AND cb.BetType = 913
					AND cb.custid = @CustId
					AND cb.winlostdate = b.WinLostDate
			WHERE b.BetType = 912
		END
	END

	IF EXISTS (SELECT 1 FROM @Data)
	BEGIN
		-- Get Sport Bettype Matrix
		DECLARE @SportBettype TABLE(ProductID TINYINT, Bettype SMALLINT, EventType TINYINT, RefTable TINYINT)

		DECLARE @IsTest BIT = 0

		SELECT @IsTest = dbo.f_CheckSPVersion(@@PROCID)

		INSERT INTO @SportBettype
		SELECT ProductID, BetType, EventType, RefTable
		FROM dbo.f_SportBettypeMatrix_Sel (0, 0, 0, 2, '', '', @IsTest)
		WHERE ProductID NOT IN (2, 4, 7, 9, 13, 17, 19, 24, 26, 30, 31, 33)
			AND (ProductID <> 6 OR SubProduct <> '')

		-- Get Sport/Bettype info
		UPDATE b
		SET
			Product = CASE
						WHEN s.EventType = 0 AND s.ProductID = 1 THEN 'Parlay'		-- Sportsbook Parlay
						WHEN s.EventType = 0 AND s.ProductID = 6 THEN 'OneRNG'		-- RNG Casino
						WHEN s.ProductID = 8 THEN 'Keno'
						WHEN s.ProductID = 25 THEN 'CO'								-- Cash Out
						WHEN s.EventType = 0 AND s.ProductID = 21 THEN 'AllBet'
						WHEN s.EventType = 0 AND s.ProductID = 22 THEN 'VB'			-- Macau Games
						WHEN s.EventType = 0 AND s.ProductID = 23 THEN 'NG2'
						WHEN s.EventType = 0 AND s.ProductID = 27 THEN 'ParlayVS2'	-- Betradar Virtual Sports Parlay
						WHEN s.EventType = 0 AND s.ProductID = 83 THEN 'ParlayVS4'	-- Virtual Sports 4 Parlay
						WHEN s.ProductID = 28 THEN 'Lottery'
						WHEN s.ProductID = 32 THEN 'PP'								-- Pragmatic Play Casino
						WHEN s.ProductID = 34 THEN 'CC'								-- Card Club
						WHEN s.ProductID = 36 THEN 'SG'								-- Spadegaming
						WHEN s.ProductID = 37 THEN 'NPHP'							-- NPH Promotion
						WHEN s.ProductID = 38 THEN 'VRG'							-- Virtual Games
						WHEN s.ProductID = 39 THEN 'SAG'							-- SA Gaming
						WHEN s.ProductID = 40 THEN 'TG'								-- Table Games
						WHEN s.ProductID = 42 THEN 'SBC'							-- Saba.club
						WHEN s.ProductID = 43 THEN 'I4D'							-- Indo 4D
						WHEN s.ProductID = 45 THEN 'SXG'							-- Sexy Gaming
						WHEN s.ProductID = 46 THEN 'IBCLC'							-- IBCBet Live Casino
						WHEN s.ProductID = 47 THEN 'BBIN'							-- BBIN
						WHEN s.ProductID = 49 THEN 'VS3'							-- Leap Gaming Virtual Sports 3
						WHEN s.ProductID = 50 THEN 'RNGW'							-- RNG War
						WHEN s.ProductID = 51 THEN 'WM'								-- WM
						WHEN s.ProductID = 52 THEN 'ION'							-- ION
						WHEN s.ProductID = 55 THEN 'PGS'							-- PG Soft
						WHEN s.ProductID = 56 THEN 'JK'								-- Joker
						WHEN s.ProductID = 57 THEN 'BG'								-- Big Gaming
						WHEN s.ProductID = 60 THEN 'MXG'							-- MaxGame
						WHEN s.ProductID = 61 THEN 'HB'								-- Habanero
						WHEN s.ProductID = 62 THEN 'CG'								-- CG
						WHEN s.ProductID = 63 THEN 'SLT'							-- Sports Lottery
						WHEN s.ProductID = 65 THEN 'PPL'							-- PP Live Casino
						WHEN s.ProductID = 66 THEN 'VGA'							-- VGaming
						WHEN s.ProductID = 67 THEN 'AP'								-- AdvantPlay
						WHEN s.ProductID = 68 THEN 'APM'							-- AdvantPlay Mini
						WHEN s.ProductID = 69 THEN 'BTC'							-- Bitcoin
						WHEN s.ProductID = 70 THEN 'FGGL'							-- FGG
						WHEN s.ProductID = 72 THEN 'SEA'							-- SEAL Entertainment
						WHEN s.ProductID = 73 THEN 'MGRNG'							-- MG-RNG
						WHEN s.ProductID = 74 THEN 'TIP'							-- Player Tips
						WHEN s.ProductID = 75 THEN 'JIG'							-- Jili
						WHEN s.ProductID = 76 THEN 'YB'								-- YeeBet
						WHEN s.ProductID = 77 THEN 'LG'								-- Virtual Sports 3
						WHEN s.ProductID = 78 THEN 'UUSL'							-- UU Slots
						WHEN s.ProductID = 79 THEN 'L22'							-- Live22
						WHEN s.ProductID = 86 THEN 'SNG'							-- Saba xD
						WHEN s.ProductID = 80 THEN 'WE'								-- WE Live Casino
						WHEN s.ProductID = 81 THEN 'SAC'							-- Saba Coins
						WHEN s.ProductID = 87 THEN 'FS'								-- FastSpin
						WHEN s.ProductID = 89 THEN 'FAC'							-- FA CHAI
						WHEN s.ProductID = 85 THEN 'NS'								-- Nextspin
						WHEN s.EventType = 1 AND s.ProductID = 1 THEN 'SB'			-- Sportsbook
						WHEN s.EventType = 1 AND s.ProductID = 3 THEN 'NG'			-- Number Game
						WHEN s.EventType = 1 AND s.ProductID = 5 THEN 'VS'			-- Virtual Sports Sportsbook
						WHEN s.EventType = 1 AND s.ProductID = 27 THEN 'VS2'		-- Betradar Virtual Sports
						WHEN s.EventType = 2 AND s.ProductID = 1 THEN 'Outright'
						WHEN s.EventType = 3 AND s.ProductID = 5 THEN 'VR'			-- Virtual Sports Racing
						WHEN s.EventType = 0 AND s.ProductID = 3 THEN 'H5LG'		-- Happy 5 Linked Games
						WHEN s.EventType = 1 AND s.ProductID = 83 THEN 'VS4'		-- Virtual Sports 4
						ELSE 'Unknown'
					END,
			RefTable = s.RefTable
		FROM @Data AS b
			INNER JOIN @SportBettype AS s ON b.BetType = s.BetType

		DELETE @Data
		WHERE Product = 'Unknown'
			OR Product IS NULL
			OR BetType IN (903, 904, 913, 914)

		-- Delete Soccer tickets
		IF @Date > @MoveBetsDay		-- bettrans range
		BEGIN
			-- Normal tickets
			DELETE b
			FROM @Data AS b
				INNER JOIN dbo.match AS m WITH (NOLOCK) ON b.MatchId = m.matchid
			WHERE m.sporttype = 1 AND b.Product IN ('SB', 'CO')

			-- Outright
			DELETE b
			FROM @Data AS b
				INNER JOIN dbo.outright AS o WITH (NOLOCK) ON o.orid = b.MatchId
				INNER JOIN dbo.league AS l WITH (NOLOCK) ON l.leagueid = o.leagueid
			WHERE l.sporttype = 1 AND b.Product = 'Outright'

			-- Parlay
			DELETE b
			FROM @Data AS b
			WHERE b.Product = 'Parlay'
				AND EXISTS (SELECT 1
						FROM dbo.bettransm AS bm WITH (NOLOCK)
							INNER JOIN dbo.match AS m WITH (NOLOCK) ON bm.matchid = m.matchid
						WHERE m.sporttype = 1 AND bm.refno = b.RefNo)
		END
		ELSE IF @Date BETWEEN @BalanceUpDay AND @MoveBetsDay		-- bettrans14 range
		BEGIN
			-- Normal tickets
			DELETE b
			FROM @Data AS b
				INNER JOIN dbo.match14 AS m WITH (NOLOCK) ON b.MatchId = m.matchid
			WHERE m.sporttype = 1 AND b.Product IN ('SB', 'CO')

			-- Outright
			DELETE b
			FROM @Data AS b
				INNER JOIN dbo.outright14 AS o WITH (NOLOCK) ON o.orid = b.MatchId
				INNER JOIN dbo.league AS l WITH (NOLOCK) ON l.leagueid = o.leagueid
			WHERE l.sporttype = 1 AND b.Product = 'Outright'

			-- Parlay
			DELETE b
			FROM @Data AS b
			WHERE b.Product = 'Parlay'
				AND EXISTS (SELECT 1
						FROM dbo.bettransm14 AS bm WITH (NOLOCK)
							INNER JOIN dbo.match14 AS m WITH (NOLOCK) ON bm.matchid = m.matchid
						WHERE m.sporttype = 1 AND bm.refno = b.RefNo)
		END
		ELSE IF @Date < @BalanceUpDay		-- bettrans_bk range
		BEGIN
			-- Normal tickets
			DELETE b
			FROM @Data AS b
				INNER JOIN bodb_Archive.dbo.match_bk AS m WITH (NOLOCK) ON b.MatchId = m.matchid
			WHERE m.sporttype = 1 AND b.Product IN ('SB', 'CO')

			-- Outright
			DELETE b
			FROM @Data AS b
				INNER JOIN bodb_Archive.dbo.outright_bk AS o WITH (NOLOCK) ON o.orid = b.MatchId
				INNER JOIN dbo.league AS l WITH (NOLOCK) ON l.leagueid = o.leagueid
			WHERE l.sporttype = 1 AND b.Product = 'Outright'

			-- Parlay
			DELETE b
			FROM @Data AS b
			WHERE b.Product = 'Parlay'
				AND EXISTS (SELECT 1
						FROM bodb_Archive.dbo.bettransm AS bm WITH (NOLOCK)
							INNER JOIN bodb_Archive.dbo.match_bk AS m WITH (NOLOCK) ON bm.matchid = m.matchid
						WHERE m.sporttype = 1 AND bm.refno = b.RefNo)
		END

		DECLARE @Yesterday SMALLDATETIME = DATEADD(DAY, DATEDIFF(DAY, 1, CURRENT_TIMESTAMP), 0)

		IF EXISTS (SELECT 1 FROM @Data)
		BEGIN
			-- Get data for summary ticket of multiple Bonus/Cash sub tickets
			IF EXISTS (SELECT 1 FROM @Data WHERE RefCode <> 0)
			BEGIN
				DECLARE @RefCodeTmp TABLE (
					RefCode			BIGINT,
					TransId			BIGINT,
					Stake			MONEY,
					Actual_Stake	MONEY,
					WinLost			MONEY,
					Commission		MONEY
				)

				-- Prepare temp table
				INSERT INTO @RefCodeTmp
				SELECT
					RefCode,
					MIN(TransId) AS TransId,
					SUM(Stake) AS Stake,
					SUM(Actual_Stake) AS Actual_Stake,
					SUM(WinLost) AS WinLost,
					SUM(Commission) AS Commission
				FROM @Data
				WHERE RefCode <> 0
				GROUP BY RefCode
				HAVING COUNT(*) > 1

				IF EXISTS (SELECT 1 FROM @RefCodeTmp)
				BEGIN
					-- Update data for summmary ticket
					UPDATE b
					SET
						b.Stake = r.Stake,
						b.Actual_Stake = r.Actual_Stake,
						b.WinLost = r.WinLost,
						b.Commission = r.Commission,
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

			-- Get yesterday and today running and settled bettransRnG/bettransLC tickets
			IF @Date >= @Yesterday
			BEGIN
				-- bettransRnG
				IF EXISTS (SELECT 1 FROM @Data WHERE Product IN ('VB', 'PP', 'OneRNG', 'CC', 'SG', 'SBC', 'RNGW', 'PGS', 'JK', 'MXG', 'HB', 'CG', 'VGA', 'AP', 'APM', 'SEA', 'MGRNG', 'JIG', 'L22', 'UUSL', 'SNG')
														OR RefTable = 1)
				BEGIN
					-- Running
					INSERT INTO @TmpData
					SELECT
						c.TransId AS RefNo,
						0 AS Odds,
						SUM(brng.stake) AS Stake,
						SUM(brng.actual_stake) AS Actual_Stake,
						'Running' AS Status,
						0 AS WinLost,
						0 AS Commission,
						0 AS OddsSpread
					FROM @Data AS c
						INNER JOIN dbo.bettransRnG AS brng WITH (NOLOCK) ON brng.RefNo = c.TransId
					WHERE (c.Product IN ('VB', 'PP', 'OneRNG', 'CC', 'SG', 'SBC', 'RNGW', 'PGS', 'JK', 'MXG', 'HB', 'CG', 'VGA', 'AP', 'APM', 'SEA', 'MGRNG', 'JIG', 'L22', 'UUSL', 'SNG') 
									OR c.RefTable = 1)
						AND brng.statusID IN (0, 1)
					GROUP BY
						c.TransId,
						c.Product

					-- Settled
					INSERT INTO @TmpData
					SELECT
						c.TransId AS RefNo,
						CASE
							WHEN Product IN ('OneRNG', 'PP', 'SG', 'SBC', 'VGA') THEN ISNULL(AVG(CASE WHEN brng.statusID IN (111, 112, 113) THEN brng.ContributionRate END), 0)
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
						SUM(brng.playercomm) AS Commission,
						CASE
							WHEN c.Product IN ('OneRNG', 'PP', 'SG', 'SBC', 'VGA') THEN ISNULL(SUM(brng.BetStake), 0)
							ELSE 0
						END AS OddsSpread
					FROM @Data AS c
						INNER JOIN dbo.bettransRnG AS brng WITH (NOLOCK) ON brng.RefNo = c.TransId
					WHERE (c.Product IN ('VB', 'PP', 'OneRNG', 'CC', 'SG', 'SBC', 'RNGW', 'PGS', 'JK', 'MXG', 'HB', 'CG', 'VGA', 'AP', 'APM', 'SEA', 'MGRNG', 'JIG', 'L22', 'UUSL', 'SNG') 
								OR c.RefTable = 1)
						AND brng.statusID NOT IN (0, 1)
					GROUP BY
						c.TransId,
						c.Product
				END

				-- bettransLC
				IF EXISTS (SELECT 1 FROM @Data WHERE Product IN ('Allbet', 'SAG', 'SXG', 'IBCLC', 'ION', 'WM', 'BG', 'PPL', 'FGGL', 'YB', 'WE'))
				BEGIN
					-- Running
					INSERT INTO @TmpData
					SELECT
						c.TransId AS RefNo,
						0 AS Odds,
						SUM(blc.stake) AS Stake,
						SUM(blc.actual_stake) AS Actual_Stake,
						'Running' AS Status,
						0 AS WinLost,
						0 AS Commission,
						0 AS OddsSpread
					FROM @Data AS c
						INNER JOIN dbo.bettransLC AS blc WITH (NOLOCK) ON blc.RefNo = c.TransId
					WHERE c.Product IN ('Allbet', 'SAG', 'SXG', 'IBCLC', 'ION', 'WM', 'BG', 'PPL', 'FGGL', 'YB', 'WE')
						AND blc.statusID IN (0, 1)
					GROUP BY
						c.TransId,
						c.Product

					-- Settled
					INSERT INTO @TmpData
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
						SUM(blc.playercomm) AS Commission,
						0 AS OddsSpread
					FROM @Data AS c
						INNER JOIN dbo.bettransLC AS blc WITH (NOLOCK) ON blc.RefNo = c.TransId
					WHERE c.Product IN ('Allbet', 'SAG', 'SXG', 'IBCLC', 'ION', 'WM', 'BG', 'PPL', 'FGGL', 'YB', 'WE')
						AND blc.statusID NOT IN (0, 1)
					GROUP BY
						c.TransId,
						c.Product
				END

				DELETE b
				FROM @Data AS b
				WHERE (b.Product IN ('VB', 'PP', 'OneRNG', 'CC', 'SG', 'SBC', 'RNGW', 'PGS', 'JK', 'MXG', 'CG', 'AP', 'APM', 'SEA', 'MGRNG', 'JIG', 'L22', 'SNG', 'FS', 'FAC', 'NS'
						, 'Allbet', 'SAG', 'SXG', 'IBCLC', 'ION', 'WM', 'BG', 'PPL', 'HB', 'VGA', 'FGGL', 'YB', 'WE', 'UUSL')
						OR b.RefTable = 1)
					AND NOT EXISTS (SELECT 1 FROM @TmpData WHERE RefNo = b.TransId)
			END

			-- bettrans range
			IF @Date > @MoveBetsDay
			BEGIN
				UPDATE b
				SET
					TransId = CASE
								WHEN b.Product = 'Parlay' AND b.bettype = 29 AND ISNULL(b.betid, 0) > 0 THEN b.betid
								ELSE b.transid
							END,
					SportType = CASE
									WHEN b.Product IN ('OneRNG', 'CC', 'NPHP', 'SG', 'VRG', 'SAG', 'TG', 'SBC', 'I4D', 'SXG', 'IBCLC', 'BBIN', 'ION', 
										'PGS', 'JK', 'RNGW', 'WM', 'VS3', 'BG', 'H5LG', 'MXG', 'SLT', 'PPL', 'HB', 'CG', 'VGA', 'AP', 'APM', 'FGGL', 'SEA', 'MGRNG',
										'TIP', 'JIG', 'YB', 'WE', 'L22', 'UUSL', 'SNG', 'SAC') THEN b.matchid
									WHEN b.Product = 'Keno' THEN 202	-- Keno
									WHEN b.Product = 'Lottery' THEN 220	-- Lottery
									WHEN b.Product = 'AllBet' THEN 211	-- AllBet
									WHEN b.Product = 'VB' THEN 212		-- Macau Games
									WHEN b.Product = 'NG2' AND b.bettype BETWEEN 2501 AND 2539 THEN 213 -- NG2
									WHEN b.Product = 'NG2' AND b.bettype BETWEEN 2541 AND 2579 THEN 214 -- NG2
									WHEN b.Product = 'NG2' AND b.bettype BETWEEN 2581 AND 2619 THEN 215 -- NG2
									WHEN b.Product = 'NG2' AND b.bettype BETWEEN 2621 AND 2659 THEN 216 -- NG2
									WHEN b.Product = 'NG2' AND b.bettype BETWEEN 2681 AND 2699 THEN 218 -- NG2
									WHEN b.Product = 'PP' THEN 248		-- Pragmatic Casino
									WHEN b.Product IN ('SB', 'CO', 'NG', 'VS', 'VS2', 'LG', 'VS4') THEN m.sporttype
									WHEN b.Product IN ('Outright') THEN l.sporttype
									WHEN b.Product IN ('VR') THEN vr.SportType
									WHEN b.Product IN ('BTC') THEN m3rd.sporttype
									WHEN b.RefTable = 1 THEN b.matchid
									ELSE 0
								END,
					BetTeam = CASE
									WHEN b.Product IN ('SB', 'NG', 'VS', 'VS2', 'Parlay', 'ParlayVS2', 'BTC', 'LG', 'VS4', 'ParlayVS4') THEN b.betteam
									ELSE ''
								END,
					Hdp1 = CASE
								WHEN b.Product IN ('SB', 'NG', 'VS', 'VS2', 'VR', 'Parlay', 'ParlayVS2', 'NG2', 'BTC', 'LG', 'ParlayVS4') THEN b.hdp1
								ELSE 0
							END,
					Hdp2 = CASE
								WHEN b.Product IN ('SB', 'CO', 'VS', 'VS2', 'VR', 'Parlay', 'ParlayVS2', 'NG2', 'LG', 'ParlayVS4') THEN b.hdp2
								ELSE 0
							END,
					OddsType = CASE
									WHEN b.Product IN ('SB', 'Outright', 'CO', 'NG', 'VS', 'VS2', 'LG', 'VS4') THEN b.oddstype
									ELSE 0
								END,
					Odds = CASE
								WHEN b.Product IN ('SB', 'CO', 'NG', 'VS', 'VS2', 'Outright', 'VR', 'Parlay', 'OneRNG', 'Keno', 'NG2', 'ParlayVS2', 
									'Lottery', 'VRG', 'TG', 'I4D', 'PP', 'SG', 'VS3', 'SBC', 'H5LG', 'SLT', 'VGA', 'BTC', 'LG', 'VS4', 'ParlayVS4') THEN b.odds
								ELSE 0
							END,
					MOdds = CASE
								WHEN b.Product IN ('SB', 'CO', 'NG', 'VS', 'VS2', 'Outright', 'VR', 'Parlay', 'ParlayVS2', 'LG', 'VS4', 'ParlayVS4') THEN b.modds
								ELSE 0
							END,
					Status = CASE
								WHEN b.Product = 'SB' AND b.bettype NOT IN (9, 29)
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
								WHEN b.Product = 'TG' AND b.status = 'Won' AND b.modds = 0.25 THEN 'Half Won'
								WHEN b.Product = 'TG' AND b.status = 'Lose' AND b.modds = -0.25 THEN 'Half Lose'
								ELSE b.status
							END,
					SettlementStatus = CASE
											WHEN b.Product = 'SB' THEN ISNULL(m.SettlementStatus, 0)
											ELSE 0
										END,
					WinLost = b.winlost - b.actual_stake,
					LiveIndicator = CASE
										WHEN b.Product IN ('SB', 'CO', 'NG', 'VS', 'VS2', 'LG') THEN b.liveindicator
										ELSE 0
									END,
					LiveHomeScore = CASE
										WHEN b.Product IN ('SB', 'CO', 'NG', 'VS', 'VS2', 'Outright', 'VR', 'NG2', 'LG') THEN b.livehomescore
										ELSE 0
									END,
					LiveAwayScore = CASE
										WHEN b.Product IN ('SB', 'CO', 'NG', 'VS', 'VS2', 'Outright', 'VR', 'LG') THEN b.liveawayscore
										ELSE 0
									END,
					LeagueId = CASE
									WHEN b.Product IN ('SB', 'CO', 'NG', 'VS', 'VS2', 'LG', 'VS4') THEN m.leagueid
									WHEN b.Product IN ('Outright') THEN o.leagueid
									WHEN b.Product IN ('VR') THEN vr.LeagueID
									ELSE 0
								END,
					MatchId = CASE
									WHEN b.Product IN ('NG2') THEN b.betdaqid
									WHEN b.Product IN ('SB', 'CO', 'NG', 'VS', 'VS2', 'LG', 'VS4') THEN m.matchid
									WHEN b.Product IN ('Outright') THEN o.orid
									WHEN b.Product IN ('VR', 'BTC') THEN b.matchid
									WHEN b.Product = 'TIP' THEN ISNULL(CAST(('<xml>' + b.ExtraInfo + '</xml>') AS XML).value('data(/xml/p74/@m)[1]','INT'), 0)
									ELSE 0
								END,
					MatchCode = CASE
									WHEN b.Product IN ('SB', 'CO', 'NG', 'VS', 'VS2', 'LG', 'VS4') THEN m.matchcode
									WHEN b.Product IN ('Outright') THEN o.matchcode
									WHEN b.Product IN ('VR') THEN CONVERT(NVARCHAR(50), vo.RacerNum)
									ELSE ''
								END,
					Race = CASE
								WHEN b.Product IN ('Outright') THEN o.groupmatch
								WHEN b.Product IN ('VR') THEN CONVERT(NVARCHAR(50), b.oddsid)
								ELSE ''
							END,
					EventDate = CASE
									WHEN b.Product IN ('SB', 'CO') THEN m.GlobalShowTime
									WHEN b.Product IN ('NG', 'VS', 'VS2', 'LG', 'VS4') THEN m.eventdate
									WHEN b.Product IN ('Outright') THEN o.eventdate
									WHEN b.Product IN ('VR') THEN vo.EventDate
									WHEN b.Product IN ('BTC') THEN m3rd.EndTime
									ELSE b.winlostdate
								END,
					HomeId = CASE
								WHEN b.Product IN ('SB', 'CO', 'NG', 'VS', 'VS2', 'LG', 'VS4') THEN m.homeid
								WHEN b.Product IN ('Outright') THEN o.teamid
								WHEN b.Product IN ('VR') THEN vo.RacerID
								ELSE 0
							END,
					AwayId = CASE
								WHEN b.Product IN ('SB', 'CO', 'NG', 'VS', 'VS2', 'LG', 'VS4') THEN m.awayid
								ELSE 0
							END,
					IsNeutral = CASE
									WHEN b.Product IN ('SB', 'CO', 'NG', 'VS', 'VS2', 'LG') THEN ISNULL(m.IsNeutral, 0)
									ELSE 0
								END,
					ShowTime = CASE
									WHEN b.Product IN ('VS', 'VS2', 'LG', 'VS4') THEN CONVERT(NVARCHAR(50), m.kickofftime)
									WHEN b.Product IN ('SB', 'CO', 'NG') THEN ISNULL(m.showtime, '')
									WHEN b.Product IN ('VR') THEN CONVERT(NVARCHAR(50), vr.EventTime)
									ELSE ''
								END,
					BetCheck = CASE
									WHEN b.Product IN ('SB', 'CO', 'Parlay', 'ParlayVS2', 'VRG', 'H5LG', 'SLT', 'ParlayVS4') THEN ISNULL(b.betcheck, '')
									WHEN b.Product IN ('Keno') THEN ISNULL(b.comstatus, '')
									ELSE ''
								END,
					ComStatus = CASE WHEN b.comstatus = '1' THEN '1' ELSE '0' END,
					TransDesc = CASE
									WHEN b.Product IN ('SB', 'CO', 'VS2', 'OneRNG', 'CC', 'SG', 'Keno', 'VB', 'NG2', 'Lottery', 
										'PP', 'VRG', 'TG', 'I4D', 'PGS', 'JK', 'VS3', 'H5LG', 'SLT', 'HB', 'CG', 'AP', 'APM', 'SEA', 'LG', 'VS4') THEN ISNULL(b.transdesc, '')
									ELSE ''
								END,
					OddsSpread = CASE
									WHEN b.Product IN ('SB', 'CO', 'OneRNG', 'PP', 'SG', 'SBC', 'VGA', 'Parlay') THEN ISNULL(b.oddsspread, 0)
									ELSE 0
								END,
					BetdaqId = CASE
									WHEN b.Product IN ('SB', 'CO') THEN ISNULL(b.betdaqid, -1)
									ELSE -1
								END,
					ExtraInfo = ISNULL(b.ExtraInfo, ''),
					WalletType = CASE
									WHEN b.Product IN ('SB') THEN ISNULL(b.WalletType, 0)
									ELSE 0
								END,
					RefCode = CASE
									WHEN b.Product IN ('SB') THEN ISNULL(b.RefCode, 0)
									ELSE 0
								END,
					CurrencyId = CASE
									WHEN b.Product IN ('H5LG', 'SLT') THEN b.CurrencyId
									ELSE 0
								END,
					SiteId = CASE
								WHEN b.Product IN ('VRG', 'H5LG', 'SLT') THEN b.SiteId
								ELSE ''
							END
				FROM @Data AS b
					LEFT JOIN dbo.match AS m WITH (NOLOCK) ON b.Product IN ('SB', 'CO', 'NG', 'VS', 'VS2', 'LG', 'VS4') AND b.matchid = m.matchid
					LEFT JOIN dbo.outright AS o WITH (NOLOCK) ON b.Product IN ('Outright') AND b.matchid = o.orid
					LEFT JOIN dbo.League AS l WITH (NOLOCK) ON b.Product IN ('Outright') AND o.leagueid = l.leagueid
					LEFT JOIN dbo.VSOutright AS vo WITH (NOLOCK) ON b.Product IN ('VR') AND b.oddsid = vo.Orid
					LEFT JOIN dbo.VSRaceInfo AS vr WITH (NOLOCK) ON b.Product IN ('VR') AND vr.EventID = vo.EventID
					LEFT JOIN dbo.match3rd AS m3rd WITH (NOLOCK) ON b.Product IN ('BTC') AND b.matchid = m3rd.match3rdid
				WHERE b.TableID = 1
					AND (b.Product NOT IN ('VB', 'PP', 'OneRNG', 'CC', 'SG', 'SBC', 'RNGW', 'PGS', 'JK', 'MXG', 'HB', 'CG', 'AP', 'APM', 'SEA', 'MGRNG', 'JIG', 'L22', 'SNG', 'FS', 'FAC', 'NS',
							'Allbet', 'SAG', 'SXG', 'IBCLC', 'ION', 'WM', 'BG', 'PPL', 'VGA', 'FGGL', 'YB', 'WE', 'UUSL')
						OR b.WinLostDate < @Yesterday)

				-- Get match info for Player Tips
				IF EXISTS (SELECT 1 FROM @Data WHERE Product = 'TIP' AND TableID = 1)
				BEGIN
					UPDATE b
					SET
						LeagueId = m.leagueid,
						HomeId = m.homeid,
						AwayId = m.awayid,
						EventDate = m.GlobalShowTime
					FROM @Data AS b
						INNER JOIN dbo.match AS m WITH (NOLOCK) ON m.matchid = b.MatchId
					WHERE Product = 'TIP' 
						AND b.TableID = 1
				END

				-- translog
				UPDATE b
				SET SportType = CASE
									WHEN b.Product = 'Keno' THEN 202
									WHEN b.Product = 'Lottery' THEN 220			-- Lottery
									WHEN b.Product IN ('VRG', 'TG', 'I4D', 'VS3', 'H5LG', 'SLT') THEN b.ProductId		-- Virtual Games, Table Games, Indo 4D
									ELSE 0
								END,
					BetId = 0,
					BetTeam = '',
					Hdp1 = 0,
					Hdp2 = 0,
					Odds = CASE
								WHEN b.Product IN ('VRG', 'TG', 'I4D', 'VS3', 'H5LG', 'SLT') THEN b.Odds
								ELSE 0
							END,
					OddsType = 0,
					OddsId = 0,
					MOdds = 0,
					SettlementStatus = 0,
					WinLost = 0,
					Commission = 0,
					LiveIndicator = 0,
					LiveHomeScore = 0,
					LiveAwayScore = 0,
					LeagueId = 0,
					MatchId = 0,
					MatchCode = '',
					Race = '',
					EventDate = b.winlostdate,
					HomeId = 0,
					AwayId = 0,
					IsNeutral = 0,
					ShowTime = '',
					BetCheck = CASE
									WHEN b.Product IN ('H5LG') THEN b.Gameid3rd
									WHEN b.Product IN ('VRG', 'SLT') THEN b.TranId3rd
									WHEN b.Product IN ('Keno') THEN ISNULL(b.custom2, '')
									WHEN b.Product IN ('VS3') THEN ISNULL(b.custom1, '')
									ELSE ''
								END,
					ComStatus = 0,
					TransDesc = CASE
									WHEN b.Product IN ('Keno', 'Lottery', 'VRG', 'TG', 'I4D', 'VS3', 'H5LG', 'SLT') THEN b.transdesc
									ELSE ''
								END,
					OddsSpread = 0,
					BetdaqId = -1,
					ExtraInfo = ISNULL(b.ExtraInfo, ''),
					CurrencyId = CASE
									WHEN b.Product IN ('H5LG', 'SLT') THEN b.CurrencyId
									ELSE 0
								END,
					SiteId = CASE
								WHEN b.Product IN ('H5LG', 'SLT') THEN b.SiteId
								ELSE ''
							END
				FROM @Data AS b
				WHERE TableID = 4

				-- bettransRnG & bettransLC yesterday and today tickets
				DECLARE @TmpCasinoData TABLE (
					TransId				BIGINT,
					RefNo				BIGINT,
					CustId				INT,
					Creator				INT,
					Currency			SMALLINT,
					SportType			SMALLINT,
					BetType				SMALLINT,
					BetId				BIGINT,
					BetTeam				NVARCHAR(20),
					Hdp1				SMALLMONEY,
					Hdp2				SMALLMONEY,
					OddsId				INT,
					OddsType			TINYINT,
					Odds				MONEY,
					MOdds				MONEY,
					OddsSpread			MONEY,
					Stake				MONEY,
					Actual_Stake		MONEY,
					WinLost				MONEY,
					Commission			MONEY,
					Status				NVARCHAR(10),
					SettlementStatus	TINYINT,
					SecAcceptFlag		BIT,
					CheckTime			DATETIME,
					TransDate			DATETIME,
					WinLostDate			SMALLDATETIME,
					LiveIndicator		BIT,
					LiveHomeScore		SMALLINT,
					LiveAwayScore		SMALLINT,
					Ip					VARCHAR(45),
					LeagueId			INT,
					MatchId				INT,
					MatchCode			NVARCHAR(50),
					Race				NVARCHAR(50),
					EventDate			DATETIME,
					HomeId				INT,
					AwayId				INT,
					IsNeutral			BIT,
					ShowTime			NVARCHAR(50),
					BetCheck			NVARCHAR(50),
					ComStatus			NVARCHAR(20),
					TransDesc			NVARCHAR(1000),
					BetdaqId			BIGINT,
					ExtraInfo			VARCHAR(1000),
					OriginalBetType		SMALLINT,
					WalletType			TINYINT,
					RefCode				BIGINT,
					ProductId			INT,
					EventId				INT,
					Custom1				NVARCHAR(50),
					Custom2				NVARCHAR(50),
					Custom3				NVARCHAR(50),
					Gameid3rd			NVARCHAR(50),
					Tranid3rd			NVARCHAR(200),
					TableID				TINYINT,
					Product				VARCHAR(30),
					CurrencyId			TINYINT,
					SiteId				VARCHAR(20),
					DeviceType			TINYINT,
					RefTable			TINYINT
				)

				INSERT INTO @TmpCasinoData
				SELECT
					b.TransId,
					b.RefNo,
					b.CustId,
					b.Creator,
					b.Currency,
					CASE
						WHEN b.Product IN ('OneRNG', 'CC', 'SG', 'SAG', 'SBC', 'SXG', 'IBCLC', 'ION', 'RNGW', 'PGS', 'JK', 'WM', 'BG', 'MXG', 'PPL', 'HB', 'CG', 'VGA', 'AP', 'APM', 'FGGL', 'SEA', 'MGRNG', 'JIG', 'YB', 'WE', 'L22', 'UUSL', 'SNG') THEN b.matchid
						WHEN b.Product = 'AllBet' THEN 211 -- AllBet
						WHEN b.Product = 'VB' THEN 212 -- Macau Games
						WHEN b.Product = 'PP' THEN 248 -- Pragmatic Casino
						WHEN b.RefTable = 1 THEN b.matchid
						ELSE 0
					END AS SportType,
					b.BetType,
					b.BetId,
					'' AS BetTeam,
					0 AS Hdp1,
					0 AS Hdp2,
					b.OddsId,
					0 AS OddsType,
					x.Odds,
					0 AS MOdds,
					CASE
						WHEN b.Product IN ('OneRNG', 'PP', 'SG', 'SBC', 'VGA') THEN x.OddsSpread
						ELSE 0
					END AS OddsSpread,
					x.Stake,
					x.Actual_Stake,
					x.WinLost,
					x.Commission,
					x.Status,
					0 AS SettlementStatus,
					b.SecAcceptFlag,
					b.CheckTime,
					b.TransDate,
					b.WinLostDate,
					0 AS LiveIndicator,
					0 AS LiveHomeScore,
					0 AS LiveAwayScore,
					b.Ip,
					0 AS LeagueId,
					0 AS MatchId,
					'' AS MatchCode,
					'' AS Race,
					b.winlostdate AS EventDate,
					0 AS HomeId,
					0 AS AwayId,
					0 AS IsNeutral,
					'' AS ShowTime,
					'' AS BetCheck,
					CASE WHEN b.comstatus = '1' THEN '1' ELSE '0' END AS ComStatus,
					CASE
						WHEN b.Product IN ('OneRNG', 'VB', 'PP', 'CC', 'SG', 'PGS', 'JK', 'HB', 'CG', 'AP', 'APM', 'SEA', 'MGRNG', 'YB', 'WE') THEN b.transdesc
						ELSE ''
					END AS TransDesc,
					-1 AS BetdaqId,
					'' AS ExtraInfo,
					b.OriginalBetType,
					b.WalletType,
					b.RefCode,
					b.ProductId,
					b.EventId,
					b.Custom1,
					b.Custom2,
					b.Custom3,
					b.Gameid3rd,
					b.Tranid3rd,
					b.TableID,
					b.Product,
					b.CurrencyId,
					b.SiteId,
					b.DeviceType,
					b.RefTable
				FROM @Data AS b
					INNER JOIN @TmpData AS x ON x.RefNo = b.TransId
				WHERE (b.Product IN ('VB', 'PP', 'OneRNG', 'CC', 'SG', 'SBC', 'RNGW', 'PGS', 'JK', 'MXG', 'HB', 'CG', 'VGA', 'AP', 'APM', 'SEA', 'MGRNG', 'JIG', 'L22', 'SNG', 
						'Allbet', 'SAG', 'SXG', 'IBCLC', 'ION', 'WM', 'BG', 'PPL', 'FGGL', 'YB', 'WE', 'UUSL')
						OR b.RefTable = 1)
					AND b.WinLostDate >= @Yesterday

				DELETE FROM @Data
				WHERE (Product IN ('VB', 'PP', 'OneRNG', 'CC', 'SG', 'SBC', 'RNGW', 'PGS', 'JK', 'MXG', 'HB', 'CG', 'VGA', 'AP', 'APM', 'SEA', 'MGRNG', 'JIG', 'L22', 'SNG', 'FS', 'FAC', 'NS',
						'Allbet', 'SAG', 'SXG', 'IBCLC', 'ION', 'WM', 'BG', 'PPL', 'FGGL', 'YB', 'WE', 'UUSL')
						OR RefTable = 1)
					AND WinLostDate >= @Yesterday

				INSERT INTO @Data
				SELECT * FROM @TmpCasinoData

				-- Get ticket detail
				-- Virtual Sports Racing
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
				FROM @Data AS c
					INNER JOIN dbo.bettransm AS bm WITH (NOLOCK) ON c.RefNo = bm.refno
				WHERE c.Product = 'VR' AND bm.custid = @CustId

			END
			ELSE IF @Date BETWEEN @BalanceUpDay AND @MoveBetsDay		-- bettrans14 range
			BEGIN
				UPDATE b
				SET
					TransId = CASE
								WHEN b.Product = 'Parlay' AND b.bettype = 29 AND ISNULL(b.betid, 0) > 0 THEN b.betid
								ELSE b.transid
							END,
					SportType = CASE
									WHEN b.Product IN ('OneRNG', 'CC', 'NPHP', 'SG', 'VRG', 'SAG', 'TG', 'SBC', 'I4D', 'SXG', 'IBCLC', 
										'BBIN', 'ION', 'RNGW', 'PGS', 'JK', 'WM', 'VS3', 'BG', 'H5LG', 'MXG', 'SLT', 'PPL', 'HB', 'CG', 'VGA', 'AP', 'APM', 'FGGL', 
										'SEA', 'MGRNG', 'JIG', 'TIP', 'YB', 'WE', 'L22', 'UUSL', 'SNG', 'SAC') THEN b.matchid
									WHEN b.Product = 'Keno' THEN 202	-- Keno
									WHEN b.Product = 'Lottery' THEN 220	-- Lottery
									WHEN b.Product = 'AllBet' THEN 211	-- AllBet
									WHEN b.Product = 'VB' THEN 212		-- Macau Games
									WHEN b.Product = 'NG2' AND b.bettype BETWEEN 2501 AND 2539 THEN 213 -- NG2
									WHEN b.Product = 'NG2' AND b.bettype BETWEEN 2541 AND 2579 THEN 214 -- NG2
									WHEN b.Product = 'NG2' AND b.bettype BETWEEN 2581 AND 2619 THEN 215 -- NG2
									WHEN b.Product = 'NG2' AND b.bettype BETWEEN 2621 AND 2659 THEN 216 -- NG2
									WHEN b.Product = 'NG2' AND b.bettype BETWEEN 2681 AND 2699 THEN 218 -- NG2
									WHEN b.Product = 'PP' THEN 248		-- Pragmatic Casino
									WHEN b.Product IN ('SB', 'CO', 'NG', 'VS', 'VS2', 'LG', 'VS4') THEN m.sporttype
									WHEN b.Product IN ('Outright') THEN l.sporttype
									WHEN b.Product IN ('VR') THEN vr.SportType
									WHEN b.Product IN ('BTC') THEN m3rd.sporttype
									WHEN b.RefTable = 1 THEN b.matchid
									ELSE 0
								END,
					BetTeam = CASE
									WHEN b.Product IN ('SB', 'NG', 'VS', 'VS2', 'Parlay', 'ParlayVS2', 'BTC', 'LG', 'VS4', 'ParlayVS4') THEN b.betteam
									ELSE ''
								END,
					Hdp1 = CASE
								WHEN b.Product IN ('SB', 'NG', 'VS', 'VS2', 'VR', 'Parlay', 'ParlayVS2', 'NG2', 'BTC', 'LG', 'ParlayVS4') THEN b.hdp1
								ELSE 0
							END,
					Hdp2 = CASE
								WHEN b.Product IN ('SB', 'CO', 'VS', 'VS2', 'VR', 'Parlay', 'ParlayVS2', 'NG2', 'LG', 'ParlayVS4') THEN b.hdp2
								ELSE 0
							END,
					OddsType = CASE
									WHEN b.Product IN ('SB', 'CO', 'Outright', 'NG', 'VS', 'VS2', 'LG', 'VS4') THEN b.oddstype
									ELSE 0
								END,
					Odds = CASE
								WHEN b.Product IN ('SB', 'CO', 'NG', 'VS', 'VS2', 'Outright', 'VR', 'Parlay', 'OneRNG', 'Keno', 'NG2', 
									'ParlayVS2', 'Lottery', 'VRG', 'TG', 'I4D', 'PP', 'SG', 'VS3', 'SBC', 'H5LG', 'SLT', 'VGA', 'BTC', 'LG', 'VS4', 'ParlayVS4') THEN b.odds
								ELSE 0
							END,
					MOdds = CASE
								WHEN b.Product IN ('SB', 'CO', 'NG', 'VS', 'VS2', 'Outright', 'VR', 'Parlay', 'ParlayVS2', 'LG', 'VS4', 'ParlayVS4') THEN b.modds
								ELSE 0
							END,
					Status = CASE
								WHEN b.Product = 'TG' AND b.status = 'Won' AND b.modds = 0.25 THEN 'Half Won'
								WHEN b.Product = 'TG' AND b.status = 'Lose' AND b.modds = -0.25 THEN 'Half Lose'
								ELSE b.status
							END,
					SettlementStatus = 0,
					WinLost = b.winlost - b.actual_stake,
					LiveIndicator = CASE
										WHEN b.Product IN ('SB', 'CO', 'NG', 'VS', 'VS2', 'LG') THEN b.liveindicator
										ELSE 0
									END,
					LiveHomeScore = CASE
										WHEN b.Product IN ('SB', 'CO', 'NG', 'VS', 'VS2', 'Outright', 'VR', 'NG2', 'LG') THEN b.livehomescore
										ELSE 0
									END,
					LiveAwayScore = CASE
										WHEN b.Product IN ('SB', 'CO', 'NG', 'VS', 'VS2', 'Outright', 'VR', 'LG') THEN b.liveawayscore
										ELSE 0
									END,
					LeagueId = CASE
									WHEN b.Product IN ('SB', 'CO', 'NG', 'VS', 'VS2', 'LG') THEN m.leagueid
									WHEN b.Product IN ('Outright') THEN o.leagueid
									WHEN b.Product IN ('VR') THEN vr.LeagueID
									ELSE 0
								END,
					MatchId = CASE
									WHEN b.Product IN ('NG2') THEN b.betdaqid
									WHEN b.Product IN ('SB', 'CO', 'NG', 'VS', 'VS2', 'LG', 'VS4') THEN m.matchid
									WHEN b.Product IN ('Outright') THEN o.orid
									WHEN b.Product IN ('VR', 'BTC') THEN b.matchid
									WHEN b.Product = 'TIP' THEN ISNULL(CAST(('<xml>' + b.ExtraInfo + '</xml>') AS XML).value('data(/xml/p74/@m)[1]','INT'), 0)
									ELSE 0
								END,
					MatchCode = CASE
									WHEN b.Product IN ('SB', 'CO', 'NG', 'VS', 'VS2', 'LG', 'VS4') THEN m.matchcode
									WHEN b.Product IN ('Outright') THEN o.matchcode
									WHEN b.Product IN ('VR') THEN CONVERT(NVARCHAR(50), vo.RacerNum)
									ELSE ''
								END,
					Race = CASE
								WHEN b.Product IN ('Outright') THEN o.groupmatch
								WHEN b.Product IN ('VR') THEN CONVERT(NVARCHAR(50), b.oddsid)
								ELSE ''
							END,
					EventDate = CASE
									WHEN b.Product IN ('SB', 'CO') THEN m.GlobalShowTime
									WHEN b.Product IN ('NG', 'VS', 'VS2', 'LG') THEN m.eventdate
									WHEN b.Product IN ('Outright') THEN o.eventdate
									WHEN b.Product IN ('VR') THEN vo.EventDate
									ELSE b.winlostdate
								END,
					HomeId = CASE
								WHEN b.Product IN ('SB', 'CO', 'NG', 'VS', 'VS2', 'LG', 'VS4') THEN m.homeid
								WHEN b.Product IN ('Outright') THEN o.teamid
								WHEN b.Product IN ('VR') THEN vo.RacerID
								ELSE 0
							END,
					AwayId = CASE
								WHEN b.Product IN ('SB', 'CO', 'NG', 'VS', 'VS2', 'LG', 'VS4') THEN m.awayid
								ELSE 0
							END,
					IsNeutral = CASE
									WHEN b.Product IN ('SB', 'CO', 'NG', 'VS', 'VS2', 'LG') THEN ISNULL(m.IsNeutral, 0)
									ELSE 0
								END,
					ShowTime = CASE
									WHEN b.Product IN ('VS', 'VS2', 'LG', 'VS4') THEN CONVERT(NVARCHAR(50), m.kickofftime)
									WHEN b.Product IN ('SB', 'CO', 'NG') THEN ISNULL(m.showtime, '')
									WHEN b.Product IN ('VR') THEN CONVERT(NVARCHAR(50), vr.EventTime)
									ELSE ''
								END,
					BetCheck = CASE
									WHEN b.Product IN ('SB', 'CO', 'Parlay', 'ParlayVS2', 'VRG', 'H5LG', 'SLT', 'ParlayVS4') THEN ISNULL(b.betcheck, '')
									WHEN b.Product IN ('Keno') THEN ISNULL(b.comstatus, '')
									ELSE ''
								END,
					ComStatus = CASE WHEN b.comstatus = '1' THEN '1' ELSE '0' END,
					TransDesc = CASE
									WHEN b.Product IN ('SB', 'CO', 'VS2', 'OneRNG', 'CC', 'SG', 'Keno', 'VB', 'NG2', 'Lottery', 
										'PP', 'VRG', 'TG', 'I4D', 'PGS', 'JK', 'VS3', 'H5LG', 'SLT', 'HB', 'CG', 'AP', 'APM', 'SEA', 'LG', 'VS4') THEN ISNULL(b.transdesc, '')
									ELSE ''
								END,
					OddsSpread = CASE
									WHEN b.Product IN ('SB', 'CO', 'OneRNG', 'PP', 'SG', 'SBC', 'VGA', 'Parlay') THEN ISNULL(b.oddsspread, 0)
									ELSE 0
								END,
					BetdaqId = CASE
									WHEN b.Product IN ('SB', 'CO') THEN ISNULL(b.betdaqid, -1)
									ELSE -1
								END,
					ExtraInfo = ISNULL(b.ExtraInfo, ''),
					WalletType = CASE
									WHEN b.Product IN ('SB') THEN ISNULL(b.WalletType, 0)
									ELSE 0
								END,
					RefCode = CASE
									WHEN b.Product IN ('SB') THEN ISNULL(b.RefCode, 0)
									ELSE 0
								END,
					CurrencyId = CASE
									WHEN b.Product IN ('H5LG', 'SLT') THEN b.CurrencyId
									ELSE 0
								END,
					SiteId = CASE
								WHEN b.Product IN ('VRG', 'H5LG', 'SLT') THEN b.SiteId
								ELSE ''
							END
				FROM @Data AS b
					LEFT JOIN dbo.match14 AS m WITH (NOLOCK) ON b.Product IN ('SB', 'CO', 'NG', 'VS', 'VS2', 'LG', 'VS4') AND b.matchid = m.matchid
					LEFT JOIN dbo.outright14 AS o WITH (NOLOCK) ON b.Product IN ('Outright') AND b.matchid = o.orid
					LEFT JOIN dbo.League AS l WITH (NOLOCK) ON b.Product IN ('Outright') AND o.leagueid = l.leagueid
					LEFT JOIN dbo.VSOutright14 AS vo WITH (NOLOCK) ON b.Product IN ('VR') AND b.oddsid = vo.Orid
					LEFT JOIN dbo.VSRaceInfo14 AS vr WITH (NOLOCK) ON b.Product IN ('VR') AND vr.EventID = vo.EventID
					LEFT JOIN dbo.match3rd14 AS m3rd WITH (NOLOCK) ON b.Product IN ('BTC') AND b.matchid = m3rd.match3rdid
				WHERE b.TableID = 2

				-- Get match info for Player Tips
				IF EXISTS (SELECT 1 FROM @Data WHERE Product = 'TIP' AND TableID = 2)
				BEGIN
					UPDATE b
					SET
						LeagueId = m.leagueid,
						HomeId = m.homeid,
						AwayId = m.awayid,
						EventDate = m.GlobalShowTime
					FROM @Data AS b
						INNER JOIN dbo.match14 AS m WITH (NOLOCK) ON m.matchid = b.MatchId
					WHERE Product = 'TIP' 
						AND b.TableID = 2
				END

				-- Get ticket detail
				-- Virtual Sports Racing
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
				FROM @Data AS c
					INNER JOIN dbo.bettransm14 AS bm WITH (NOLOCK) ON c.RefNo = bm.refno
				WHERE c.Product = 'VR' AND bm.custid = @CustId
	
			END
			ELSE IF @Date < @BalanceUpDay		-- bettrans_bk range
			BEGIN
				UPDATE b
				SET
					TransId = CASE
								WHEN b.Product = 'Parlay' AND b.bettype = 29 AND ISNULL(b.betid, 0) > 0 THEN b.betid
								ELSE b.transid
							END,
					SportType = CASE
									WHEN b.Product IN ('OneRNG', 'CC', 'NPHP', 'SG', 'VRG', 'SAG', 'TG', 'SBC', 'I4D', 'SXG', 'IBCLC', 
										'BBIN', 'ION', 'RNGW', 'PGS', 'JK', 'WM', 'VS3', 'BG', 'H5LG', 'MXG', 'SLT', 'PPL', 'HB', 'CG', 'VGA', 'AP', 'APM', 'FGGL', 
										'SEA', 'MGRNG', 'JIG', 'TIP', 'YB', 'WE', 'L22', 'UUSL', 'SAC', 'SNG') THEN b.matchid
									WHEN b.Product = 'Keno' THEN 202	-- Keno
									WHEN b.Product = 'Lottery' THEN 220	-- Lottery
									WHEN b.Product = 'AllBet' THEN 211	-- AllBet
									WHEN b.Product = 'VB' THEN 212		-- Macau Games
									WHEN b.Product = 'NG2' AND b.bettype BETWEEN 2501 AND 2539 THEN 213 -- NG2
									WHEN b.Product = 'NG2' AND b.bettype BETWEEN 2541 AND 2579 THEN 214 -- NG2
									WHEN b.Product = 'NG2' AND b.bettype BETWEEN 2581 AND 2619 THEN 215 -- NG2
									WHEN b.Product = 'NG2' AND b.bettype BETWEEN 2621 AND 2659 THEN 216 -- NG2
									WHEN b.Product = 'NG2' AND b.bettype BETWEEN 2681 AND 2699 THEN 218 -- NG2
									WHEN b.Product = 'PP' THEN 248		-- Pragmatic Casino
									WHEN b.Product IN ('SB', 'CO', 'NG', 'VS', 'VS2', 'LG', 'VS4') THEN m.sporttype
									WHEN b.Product IN ('Outright') THEN l.sporttype
									WHEN b.Product IN ('VR') THEN vr.SportType
									WHEN b.Product IN ('BTC') THEN m3rd.sporttype
									WHEN b.RefTable = 1 THEN b.matchid
									ELSE 0
								END,
					BetTeam = CASE
									WHEN b.Product IN ('SB', 'NG', 'VS', 'VS2', 'Parlay', 'ParlayVS2', 'BTC', 'LG', 'VS4', 'ParlayVS4') THEN b.betteam
									ELSE ''
								END,
					Hdp1 = CASE
								WHEN b.Product IN ('SB', 'NG', 'VS', 'VS2', 'VR', 'Parlay', 'ParlayVS2', 'NG2', 'BTC', 'LG', 'ParlayVS4') THEN b.hdp1
								ELSE 0
							END,
					Hdp2 = CASE
								WHEN b.Product IN ('SB', 'CO', 'VS', 'VS2', 'VR', 'Parlay', 'ParlayVS2', 'NG2', 'LG', 'ParlayVS4') THEN b.hdp2
								ELSE 0
							END,
					OddsType = CASE
									WHEN b.Product IN ('SB', 'CO', 'Outright', 'NG', 'VS', 'VS2', 'LG', 'VS4') THEN b.oddstype
									ELSE 0
								END,
					Odds = CASE
								WHEN b.Product IN ('SB', 'CO', 'NG', 'VS', 'VS2', 'Outright', 'VR', 'Parlay', 'OneRNG', 'Keno', 'NG2', 
									'ParlayVS2', 'Lottery', 'VRG', 'TG', 'I4D', 'PP', 'SG', 'VS3', 'SBC', 'H5LG', 'SLT', 'VGA', 'BTC', 'LG', 'VS4', 'ParlayVS4') THEN b.odds
								ELSE 0
							END,
					MOdds = CASE
								WHEN b.Product IN ('SB', 'CO', 'NG', 'VS', 'VS2', 'Outright', 'VR', 'Parlay', 'ParlayVS2', 'LG', 'VS4', 'ParlayVS4') THEN b.modds
								ELSE 0
							END,
					Status = CASE
								WHEN b.Product = 'TG' AND b.status = 'Won' AND b.modds = 0.25 THEN 'Half Won'
								WHEN b.Product = 'TG' AND b.status = 'Lose' AND b.modds = -0.25 THEN 'Half Lose'
								ELSE b.status
							END,
					SettlementStatus = 0,
					WinLost = b.winlost - b.actual_stake,
					LiveIndicator = CASE
										WHEN b.Product IN ('SB', 'CO', 'NG', 'VS', 'VS2', 'LG') THEN b.liveindicator
										ELSE 0
									END,
					LiveHomeScore = CASE
										WHEN b.Product IN ('SB', 'CO', 'NG', 'VS', 'VS2', 'Outright', 'VR', 'NG2', 'LG') THEN b.livehomescore
										ELSE 0
									END,
					LiveAwayScore = CASE
										WHEN b.Product IN ('SB', 'CO', 'NG', 'VS', 'VS2', 'Outright', 'VR', 'LG') THEN b.liveawayscore
										ELSE 0
									END,
					LeagueId = CASE
									WHEN b.Product IN ('SB', 'CO', 'NG', 'VS', 'VS2', 'LG', 'VS4') THEN m.leagueid
									WHEN b.Product IN ('Outright') THEN o.leagueid
									WHEN b.Product IN ('VR') THEN vr.LeagueID
									ELSE 0
								END,
					MatchId = CASE
									WHEN b.Product IN ('NG2') THEN b.betdaqid
									WHEN b.Product IN ('SB', 'CO', 'NG', 'VS', 'VS2', 'LG', 'VS4') THEN m.matchid
									WHEN b.Product IN ('Outright') THEN o.orid
									WHEN b.Product IN ('VR', 'BTC') THEN b.matchid
									WHEN b.Product = 'TIP' THEN ISNULL(CAST(('<xml>' + b.ExtraInfo + '</xml>') AS XML).value('data(/xml/p74/@m)[1]','INT'), 0)
									ELSE 0
								END,
					MatchCode = CASE
									WHEN b.Product IN ('SB', 'CO', 'NG', 'VS', 'VS2', 'LG', 'VS4') THEN m.matchcode
									WHEN b.Product IN ('Outright') THEN o.matchcode
									WHEN b.Product IN ('VR') THEN CONVERT(NVARCHAR(50), vo.RacerNum)
									ELSE ''
								END,
					Race = CASE
								WHEN b.Product IN ('Outright') THEN o.groupmatch
								WHEN b.Product IN ('VR') THEN CONVERT(NVARCHAR(50), b.oddsid)
								ELSE ''
							END,
					EventDate = CASE
									WHEN b.Product IN ('SB', 'CO') THEN m.GlobalShowTime
									WHEN b.Product IN ('NG', 'VS', 'VS2', 'LG', 'VS4') THEN m.eventdate
									WHEN b.Product IN ('Outright') THEN o.eventdate
									WHEN b.Product IN ('VR') THEN vo.EventDate
									WHEN b.Product IN ('BTC') THEN m3rd.EndTime
									ELSE b.winlostdate
								END,
					HomeId = CASE
								WHEN b.Product IN ('SB', 'CO', 'NG', 'VS', 'VS2', 'LG', 'VS4') THEN m.homeid
								WHEN b.Product IN ('Outright') THEN o.teamid
								WHEN b.Product IN ('VR') THEN vo.RacerID
								ELSE 0
							END,
					AwayId = CASE
								WHEN b.Product IN ('SB', 'CO', 'NG', 'VS', 'VS2', 'LG', 'VS4') THEN m.awayid
								ELSE 0
							END,
					IsNeutral = CASE
									WHEN b.Product IN ('SB', 'CO', 'NG', 'VS', 'VS2', 'LG') THEN ISNULL(m.IsNeutral, 0)
									ELSE 0
								END,
					ShowTime = CASE
									WHEN b.Product IN ('VS', 'VS2', 'LG', 'VS4') THEN CONVERT(NVARCHAR(50), m.kickofftime)
									WHEN b.Product IN ('SB', 'CO', 'NG') THEN ISNULL(m.showtime, '')
									WHEN b.Product IN ('VR') THEN CONVERT(NVARCHAR(50), vr.EventTime)
									ELSE ''
								END,
					BetCheck = CASE
									WHEN b.Product IN ('SB', 'CO', 'Parlay', 'ParlayVS2', 'VRG', 'H5LG', 'SLT', 'VS4', 'ParlayVS4') THEN ISNULL(b.betcheck, '')
									WHEN b.Product IN ('Keno') THEN ISNULL(b.comstatus, '')
									ELSE ''
								END,
					ComStatus = CASE WHEN b.comstatus = '1' THEN '1' ELSE '0' END,
					TransDesc = CASE
									WHEN b.Product IN ('SB', 'CO', 'VS2', 'OneRNG', 'CC', 'SG', 'Keno', 'VB', 'NG2', 'Lottery', 
										'PP', 'VRG', 'TG', 'I4D', 'PGS', 'JK', 'VS3', 'H5LG', 'SLT', 'HB', 'CG', 'AP', 'APM', 'SEA', 'LG', 'VS4') THEN ISNULL(b.transdesc, '')
									ELSE ''
								END,
					OddsSpread = CASE
									WHEN b.Product IN ('SB', 'CO', 'OneRNG', 'PP', 'SG', 'SBC', 'VGA', 'Parlay') THEN ISNULL(b.oddsspread, 0)
									ELSE 0
								END,
					BetdaqId = CASE
									WHEN b.Product IN ('SB', 'CO') THEN ISNULL(b.betdaqid, -1)
									ELSE -1
								END,
					ExtraInfo = ISNULL(b.ExtraInfo, ''),
					WalletType = CASE
									WHEN b.Product IN ('SB') THEN ISNULL(b.WalletType, 0)
									ELSE 0
								END,
					RefCode = CASE
									WHEN b.Product IN ('SB') THEN ISNULL(b.RefCode, 0)
									ELSE 0
								END,
					Ip = dp.Ip,
					CurrencyId = CASE
									WHEN b.Product IN ('H5LG', 'SLT') THEN b.CurrencyId
									ELSE 0
								END,
					SiteId = CASE
								WHEN b.Product IN ('VRG', 'H5LG', 'SLT') THEN b.SiteId
								ELSE ''
							END
				FROM @Data AS b
					CROSS APPLY dbo.f_IP_Decompress(b.Ip) AS dp
					LEFT JOIN bodb_Archive.dbo.match_bk AS m WITH (NOLOCK) ON b.Product IN ('SB', 'CO', 'NG', 'VS', 'VS2', 'LG', 'VS4') AND b.matchid = m.matchid
					LEFT JOIN bodb_Archive.dbo.outright_bk AS o WITH (NOLOCK) ON b.Product IN ('Outright') AND b.matchid = o.orid
					LEFT JOIN dbo.League AS l WITH (NOLOCK) ON b.Product IN ('Outright') AND o.leagueid = l.leagueid
					LEFT JOIN bodb_Archive.dbo.VSOutright_bk AS vo WITH (NOLOCK) ON b.Product IN ('VR') AND b.oddsid = vo.Orid
					LEFT JOIN bodb_Archive.dbo.VSRaceInfo_bk AS vr WITH (NOLOCK) ON b.Product IN ('VR') AND vr.EventID = vo.EventID
					LEFT JOIN bodb_Archive.dbo.match3rd_bk AS m3rd WITH (NOLOCK) ON b.Product IN ('BTC') AND b.matchid = m3rd.match3rdid
				WHERE b.TableID = 3

				-- Get match info for Player Tips
				IF EXISTS (SELECT 1 FROM @Data WHERE Product = 'TIP' AND TableID = 3)
				BEGIN
					UPDATE b
					SET
						LeagueId = m.leagueid,
						HomeId = m.homeid,
						AwayId = m.awayid,
						EventDate = m.GlobalShowTime
					FROM @Data AS b
						INNER JOIN bodb_Archive.dbo.match_bk AS m WITH (NOLOCK) ON m.matchid = b.MatchId
					WHERE Product = 'TIP' 
						AND b.TableID = 3
				END

				-- Get ticket detail
				-- Virtual Sports Racing
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
				FROM @Data AS c
					INNER JOIN bodb_Archive.dbo.bettransm AS bm WITH (NOLOCK) ON c.RefNo = bm.refno
				WHERE c.Product = 'VR' AND bm.custid = @CustId
			END
		END
	END

	-- Get original odds for Mix Parlay and final odds, boost rate for Mix Parlay Boost Bonus
	IF EXISTS (SELECT 1 FROM @Data
				WHERE BetType = 29
					AND BetTeam = '1'
					AND TableID IN (1, 2))
	BEGIN
		-- Running/Waiting
		DECLARE @ParlayData TABLE (
			RefNo		BIGINT,
			BoostRate	MONEY)

		INSERT INTO @ParlayData
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
		INSERT INTO @TmpParlayData
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
		INSERT INTO @TmpParlayData
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
			b.TransDesc = CONVERT(VARCHAR(20), ISNULL(bpr.ExtraValue, ''))
		FROM @Data AS b
			INNER JOIN dbo.BetParlayResult AS bpr WITH (NOLOCK) ON bpr.RefNo = b.RefNo
		WHERE b.BetType = 29
			AND b.BetTeam = '1'
			AND TableID IN (1, 2)
			AND b.Status NOT IN ('Running', 'Waiting')
	END

	IF EXISTS (SELECT 1 FROM @Data
				WHERE BetType = 29
					AND BetTeam = '1'
					AND TableID = 3)
	BEGIN
		UPDATE b
		SET
			b.Odds = bpr.Odds,
			b.Modds = bpr.mOdds,
			b.TransDesc = CONVERT(VARCHAR(20), ISNULL(bpr.ExtraValue, ''))
		FROM @Data AS b
			INNER JOIN bodb_Archive.dbo.BetParlayResult AS bpr WITH (NOLOCK) ON bpr.RefNo = b.RefNo
		WHERE b.BetType = 29
			AND b.BetTeam = '1'
			AND b.TableID = 3
	END

	-- Get currency name
	DECLARE @CurrencyName NVARCHAR(50)

	SELECT @CurrencyName = ex.currency
	FROM dbo.custInfo AS ci WITH (NOLOCK)
		INNER JOIN dbo.Exchange AS ex WITH (NOLOCK) ON ci.currency = ex.exchangeid
	WHERE ci.custid = @CustId

	SELECT
		b.TransId,
		b.RefNo,
		b.CustId,
		b.SportType,
		b.BetType,
		b.BetId,
		b.BetTeam,
		b.Hdp1,
		b.Hdp2,
		b.OddsId,
		b.OddsType,
		b.Odds,
		b.MOdds,
		b.OddsSpread,
		b.Stake,
		b.Actual_Stake,
		b.WinLost,
		b.Commission,
		b.Status,
		b.SettlementStatus,
		b.TransDate,
		b.WinLostDate,
		b.LiveIndicator,
		b.LiveHomeScore,
		b.LiveAwayScore,
		b.Ip,
		b.LeagueId,
		b.MatchId,
		b.MatchCode,
		b.Race,
		b.EventDate,
		b.HomeId,
		b.AwayId,
		b.IsNeutral,
		b.ShowTime,
		b.BetCheck,
		b.ComStatus,
		b.TransDesc,
		b.BetdaqId,
		b.ExtraInfo,
		b.OriginalBetType,
		b.WalletType,
		b.RefCode,
		@CurrencyName AS Currency,
		u.username AS Username,
		c.username AS Creator,
		b.CurrencyId,
		b.SiteId,
		b.DeviceType
	FROM @Data AS b
		INNER JOIN dbo.custInfo AS u WITH (NOLOCK) ON u.custid = b.CustId
		INNER JOIN dbo.custInfo AS c WITH (NOLOCK) ON c.custid = b.Creator
	ORDER BY b.TransId ASC

	SELECT DISTINCT * FROM @DetailData
END
GO
