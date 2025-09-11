/*<info serverAlias="DBACC-bodb02" executers="wsv_nap" viewers="" isFunction="0" isNested="0"></info>*/

ALTER PROCEDURE [dbo].[Acc_BetList_Mem]
	@CustId				INT,
	@ShadowIds			NVARCHAR(MAX) = NULL,
	@BetType			INT				= 0,
	@StatusIdList		VARCHAR(100)	= '',
	@FromDate			SMALLDATETIME,
	@ToDate				SMALLDATETIME,
	@MoveBetsDay		SMALLDATETIME,
	@BalanceUpDay		SMALLDATETIME,
	@IsCN88				BIT				= 0,
	@ExcludeBettrans	BIT				= 0,
	@MaxTotalRow		INT				= 1000000	OUTPUT,
	@ErrCode			INT				= 0			OUTPUT,
	@ErrMsg				NVARCHAR(4000)	= ''		OUTPUT
AS

/*
	Created: 20190925@Kos
	Task: NAP Left Panel => Member Bet List
	DB: DBACC.bodb02
	Parameter's Explanation:
		- @StatusIdList:
			- 0: Running
			- 1: Waiting
			- 101: Reject
			- 102: Void (not include Abnormal Bets)
			- 103: Refund
			- 111: Draw
			- 112: Won
			- 113: Lose
			- 2: Delay Payout
			- 3: Under Settlement
			- 99: Abnormal Bets
			- 88: Cash Out

	Revisions:
		- 20190925@Kos: Create new [Redmine: #120379]
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
		- 20200422@Kos: Support status Delay Payout [Redmine: #132629]
		- 20200502@Kos: Support Table Game Half Won Half Lose [Redmine: #133323]
		- 20200507@Kos: Support IBCBet Live Casino [Redmine: #130688]
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
		- 20210525@Kos: Prevent high CPU [Redmine: #154749]
					- Add new params @MaxTotalRow INT, @ErrCode INT, @ErrMsg NVARCHAR(4000)
		- 20210705@Razor: Show Odds for Happy 5 Linked Games [Redmine: #154704]
		- 20210706@Razor: Display Decimal Odds for Decimal Odds Only Bettypes [#Redmine: 157545]
		- 20210813@Razor: Support Bitcoin [Redmine: #159041]
		- 20211004@Razor: Extend Data type of IP v6 [Redmine: #90903]
		- 20211025@Razor: Decompress IP on BK range [Redmine: #90903]
		- 20211125@Razor: Rename RNG War to Funky Games [Redmine: #132024]
		- 20211130@Razor: Check Abnormal Parlay Ticket [Redmine: #163900]
		- 20211130@Razor: Support new Cash out model [Redmine: #164903]
		- 20211223@Razor: Support Third Party Result API [Redmine: #165815]
		- 20220209@Razor: Support TxId for 3rd products [Redmine: #167320]
		- 20220215@Razor: Support SG Jackpot [Redmine: #166683]
		- 20220317@Razor: Support FGG [Redmine: #165683]
		- 20220729@Kos: Scale out DBTRANS [Redmine: #175253]
					- Add new input param @ExcludeBettrans BIT
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
		- 20230927@Razor: Support show max payout [Redmine: #194491]
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
		- 20240912@Razor: Support ON Casino [Redmine: #210026]
		- 20240920@Razor: Support VS2 - Racing sports [Redmine: #211092]
		- 20241023@Razor: Support Playtech [Redmine: #210553]
		- 20241023@Razor: Support GPI [Redmine: #207173]
		- 20241106@Razor: Support VS 5 - Virtually Sports [Redmine: #207589]
		- 20241202@Razor: Support GPI Live Casino [Redmine: #213486]
		- 20241219@Razor: Support VS6 - Betby Virtual Sports [Redmine: #212546]
		- 20241231@Razor: Support PLAY STAR [Redmine: #208023]
		- 20250213@Razor: Support ASKMESLOT [Redmine: #216976]
		- 20250218@Razor: Support SABA Keno [Redmine: #214757]
		- 20250312@Benji: Support FunkyGames [Redmine: #218176]
		- 20250326@Benji: Support Upcoming Product (HOTDOG, Kiron VS7, Microgaming Live Casino, GPI Lottery, ODIN GAMING, Playtech Live Casino ) [Redmine: #221188]
		- 20250414@Razor: Support Direct Member [Redmine: #211969]
		- 20250418@Benji: Support RichGaming [Redmine: #224687]
		- 20250423@Dave: Change datatype for ExchangeID [RedmineID: #225169]
		- 20250513@Razor: Support SabaCoins multiple wallets [Redmine: #215807]
		- 20250515@Benji: Support W Casino [RedmineID: 227510]
		- 20250515@Benji: Support Automate Integration for Betlist [Redmineid: #227997]
		- 20250730@Benji: Support Playtech RNG Jackpot - Support Automate Integration for Jackpot Betlist [Redmine: #234576]
		- 20250618@Benji: Support Playtech Live [Redmine: #230127]
*/

BEGIN
	SET NOCOUNT ON

	-- Get Sport Bettype Matrix
	DECLARE @SportBettype TABLE(ProductID TINYINT, Bettype SMALLINT, EventType TINYINT, RefTable TINYINT,  SubProduct VARCHAR (500))

	DECLARE @IsTest BIT = 0

	SELECT @IsTest = dbo.f_CheckSPVersion(@@PROCID)

	INSERT INTO @SportBettype
	SELECT ProductID, BetType, EventType, RefTable, SubProduct
	FROM dbo.f_SportBettypeMatrix_Sel (0, 0, 0, 2, '', '', @IsTest)
	WHERE ProductID NOT IN (2, 4, 7, 9, 13, 17, 19, 24, 26, 30, 31, 33)
		AND (ProductID <> 6 OR SubProduct <> '')
		AND (@BetType = 0
			OR BetType = @BetType
			OR (BetType = 903 AND @BetType = 902)
			OR (BetType = 913 AND @BetType = 912))
		AND BetType NOT IN (904, 914)

	-- Add bettypes which have the same name
	IF EXISTS ( SELECT 1 FROM @SportBettype WHERE Bettype IN (SELECT DISTINCT GroupTypeId FROM f_GroupBetType3rd()))
	BEGIN
		INSERT INTO @SportBettype
		SELECT
			s.ProductID,
			f.BetType,
			s.EventType,
			s.RefTable,
			s.SubProduct
		FROM @SportBettype AS s
			INNER JOIN (SELECT * FROM f_GroupBetType3rd() WHERE BetType <> GroupTypeId) AS f ON s.Bettype = f.GroupTypeId
		WHERE NOT EXISTS ( SELECT 1 FROM @SportBettype AS sbt WHERE sbt.Bettype = f.Bettype )
	END

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
		AWinLost			MONEY,
		MWinLost			MONEY,
		SWinLost			MONEY,
		Commission			MONEY,
		Comm				MONEY,
		AComm				MONEY,
		SComm				MONEY,
		APositionTaking		SMALLMONEY,
		MPositionTaking		SMALLMONEY,
		SPositionTaking		SMALLMONEY,
		PlayerDiscount		SMALLMONEY,
		Discount			SMALLMONEY,
		ADiscount			SMALLMONEY,
		SDiscount			SMALLMONEY,
		Status				NVARCHAR(10),
		StatusId			TINYINT,
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
		IsCashOut			TINYINT,
		CurrencyId			SMALLINT,
		SiteId				VARCHAR(20),
		DeviceType			TINYINT,
		RefTable			TINYINT,
		EventType			TINYINT,
		SubProduct			VARCHAR(500)
	)

	DECLARE @TmpData TABLE (
		RefNo			BIGINT,
		Odds			MONEY,
		Stake			MONEY,
		Actual_Stake	MONEY,
		Status			NVARCHAR(10),
		WinLost			MONEY,
		AWinLost		MONEY,
		MWinLost		MONEY,
		SWinLost		MONEY,
		Commission		MONEY,
		Comm			MONEY,
		AComm			MONEY,
		SComm			MONEY,
		APositionTaking	SMALLMONEY,
		MPositionTaking	SMALLMONEY,
		SPositionTaking	SMALLMONEY,
		PlayerDiscount	SMALLMONEY,
		Discount		SMALLMONEY,
		ADiscount		SMALLMONEY,
		SDiscount		SMALLMONEY,
		OddsSpread		MONEY		
	)

	DECLARE @OriginalStatusIdList	VARCHAR(50)

	SET @OriginalStatusIdList = @StatusIdList

	IF ',' + @StatusIdList + ',' LIKE '%,99,%'
	BEGIN
		SET @StatusIdList = @StatusIdList + ',102'
	END

	IF ',' + @StatusIdList + ',' LIKE '%,1,%'
		OR ',' + @StatusIdList + ',' LIKE '%,3,%'
	BEGIN
		SET @StatusIdList = @StatusIdList + ',0'
	END

	IF ',' + @StatusIdList + ',' LIKE '%,2,%'
	BEGIN
		SET @StatusIdList = @StatusIdList + ',0,111,112,113'
	END

	IF ',' + @StatusIdList + ',' LIKE '%,88,%'
	BEGIN
		SET @StatusIdList = @StatusIdList + ',111,112,113,2,102,103'
	END
	DECLARE @TempToDate	SMALLDATETIME,
		@TempFromDate	SMALLDATETIME

	DECLARE @Yesterday SMALLDATETIME = DATEADD(DAY, DATEDIFF(DAY, 1, CURRENT_TIMESTAMP), 0)
	
	DECLARE @TmpShadow TABLE (CustId INT)	
	INSERT INTO @TmpShadow (CustId)
	SELECT value
	FROM STRING_SPLIT(@ShadowIds, ',')
	WHERE value IS NOT NULL AND value != ''
	
	INSERT INTO @TmpShadow (CustId)
	SELECT @CustId
	
	-- bettrans range
	IF @ToDate > @MoveBetsDay AND @ExcludeBettrans = 0
	BEGIN
		IF @FromDate <= @MoveBetsDay
			SET @TempFromDate = DATEADD(DAY, 1, @MoveBetsDay)
		ELSE
			SET @TempFromDate = @FromDate

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
			AWinLost,
			MWinLost,
			SWinLost,
			Commission,
			Comm,
			AComm,
			SComm,
			APositionTaking,
			MPositionTaking,
			SPositionTaking,
			PlayerDiscount,
			Discount,
			ADiscount,
			SDiscount,
			Status,
			StatusId,
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
			b.awinlost,
			b.mwinlost,
			b.swinlost,
			b.playercomm AS Commission,
			(b.comm - b.playercomm) AS Comm,
			(b.acomm - b.comm) AS AComm,
			(b.scomm - b.acomm) AS SComm,
			b.apositiontaking,
			b.mpositiontaking,
			b.spositiontaking,
			b.playerdiscount,
			b.discount,
			b.adiscount,
			b.sdiscount,
			b.status,
			b.statusID,
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
		FROM dbo.bettrans AS b WITH (NOLOCK, INDEX = IX_custid)
			INNER JOIN @SportBettype AS s ON s.Bettype = b.bettype
			INNER JOIN @TmpShadow AS t ON t.CustId = b.CustId
		WHERE
			b.winlostdate BETWEEN @TempFromDate AND @ToDate
			AND (',' + @StatusIdList + ',' LIKE '%,' + CONVERT(VARCHAR(3), b.statusID) + ',%'
				OR (s.ProductID IN (6, 21, 22, 32, 34, 36, 39, 42, 45, 46, 50, 51, 52, 55, 56, 57, 60, 61, 62, 65, 66, 67, 68, 69, 70, 72, 73, 75, 76, 78, 79, 80, 86)
					AND b.winlostdate >= @Yesterday)		-- Don't care status of yesterday and today summary casino rows
				OR (s.RefTable IN (1, 2) AND b.winlostdate >= @Yesterday))

		-- Get more info for CashOut tickets
		IF EXISTS (SELECT TOP(1) 1 FROM @Data WHERE BetType = 911 AND TableID = 1)
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
			WHERE b.BetType = 911 AND b.TableID = 1
		END

		IF EXISTS (SELECT TOP(1) 1 FROM @Data WHERE BetType = 912 AND TableID = 1)
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
				INNER JOIN dbo.bettrans AS cob WITH (NOLOCK) ON cob.transid = b.RefNo
				INNER JOIN dbo.bettrans AS ob WITH (NOLOCK) ON ob.transid = cob.RefNo
				LEFT JOIN @Data AS cb ON cb.RefNo = b.RefNo AND cb.BetType = 913
			WHERE b.BetType = 912 AND b.TableID = 1
		END

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
			APositionTaking,
			MPositionTaking,
			SPositionTaking,
			PlayerDiscount,
			Discount,
			ADiscount,
			SDiscount,
			Status,
			StatusId,
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
			b.apositiontaking,
			b.mpositiontaking,
			b.spositiontaking,
			b.playerdiscount,
			b.discount,
			b.adiscount,
			b.sdiscount,
			b.status,
			b.statusID,
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
			AND b.winlostdate BETWEEN @TempFromDate AND @ToDate
			AND b.statusID IN (0, 1)
			AND ',' + @StatusIdList + ',' LIKE '%,' + CONVERT(VARCHAR(3), b.statusID) + ',%'
	END
	
	IF @FromDate <= @MoveBetsDay AND @ToDate >= @BalanceUpDay		-- bettrans14 range
	BEGIN
		IF @ToDate >= @MoveBetsDay
			SET @TempToDate = @MoveBetsDay
		ELSE
			SET @TempToDate = @ToDate

		IF @FromDate < @BalanceUpDay
			SET @TempFromDate = @BalanceUpDay
		ELSE
			SET @TempFromDate = @FromDate

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
			AWinLost,
			MWinLost,
			SWinLost,
			Commission,
			Comm,
			AComm,
			SComm,
			APositionTaking,
			MPositionTaking,
			SPositionTaking,
			PlayerDiscount,
			Discount,
			ADiscount,
			SDiscount,
			Status,
			StatusId,
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
			b.awinlost,
			b.mwinlost,
			b.swinlost,
			b.playercomm AS Commission,
			(b.comm - b.playercomm) AS Comm,
			(b.acomm - b.comm) AS AComm,
			(b.scomm - b.acomm) AS SComm,
			b.apositiontaking,
			b.mpositiontaking,
			b.spositiontaking,
			b.playerdiscount,
			b.discount,
			b.adiscount,
			b.sdiscount,
			b.status,
			b.statusID,
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
		FROM dbo.bettrans14 AS b WITH (NOLOCK, INDEX = IX_memberStatement14)
			INNER JOIN @TmpShadow AS t ON t.CustId = b.CustId
		WHERE b.winlostdate BETWEEN @TempFromDate AND @TempToDate
			AND ',' + @StatusIdList + ',' LIKE '%,' + CONVERT(VARCHAR(3), b.statusID) + ',%'

		-- Get more info for CashOut tickets
		IF EXISTS (SELECT TOP(1) 1 FROM @Data WHERE BetType = 911 AND TableID = 2)
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
			WHERE b.BetType = 911 AND b.TableID = 2
		END

		IF EXISTS (SELECT TOP(1) 1 FROM @Data WHERE BetType = 912 AND TableID = 2)
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
				INNER JOIN dbo.bettrans14 AS cob WITH (NOLOCK) ON cob.transid = b.RefNo
				INNER JOIN dbo.bettrans14 AS ob WITH (NOLOCK) ON ob.transid = cob.RefNo
				LEFT JOIN @Data AS cb ON cb.RefNo = b.RefNo AND cb.BetType = 913
			WHERE b.BetType = 912 AND b.TableID = 2
		END
	END

	IF @FromDate <= @BalanceUpDay		-- bettrans_bk range
	BEGIN
		IF @ToDate >= DATEADD(dd, -1, @BalanceUpDay)
			SET @TempToDate = DATEADD(dd, -1, @BalanceUpDay)
		ELSE
			SET @TempToDate = @ToDate

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
			AWinLost,
			MWinLost,
			SWinLost,
			Commission,
			Comm,
			AComm,
			SComm,
			APositionTaking,
			MPositionTaking,
			SPositionTaking,
			PlayerDiscount,
			Discount,
			ADiscount,
			SDiscount,
			Status,
			StatusId,
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
			b.awinlost,
			b.mwinlost,
			b.swinlost,
			b.playercomm AS Commission,
			(b.comm - b.playercomm) AS Comm,
			(b.acomm - b.comm) AS AComm,
			(b.scomm - b.acomm) AS SComm,
			b.apositiontaking,
			b.mpositiontaking,
			b.spositiontaking,
			b.playerdiscount,
			b.discount,
			b.adiscount,
			b.sdiscount,
			b.status,
			b.statusID,
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
			INNER JOIN @TmpShadow AS t ON t.CustId = b.CustId
		WHERE b.winlostdate BETWEEN @FromDate AND @TempToDate
			AND ',' + @StatusIdList + ',' LIKE '%,' + CONVERT(VARCHAR(3), b.statusID) + ',%'

		-- Get more info for BetTrade tickets
		IF EXISTS (SELECT TOP(1) 1 FROM @Data WHERE BetType IN (901, 902) AND TableID = 3)
		BEGIN
			UPDATE b
			SET
				b.Odds = ob.Odds,
				b.Stake = ob.Stake,
				b.LiveHomeScore = ob.livehomescore,
				b.LiveAwayScore = ob.liveawayscore,
				b.Comm = CASE
							WHEN b.BetType = 902 THEN ISNULL(cb.AWinLost, 0)
							ELSE b.Comm
						END,
				b.BetId = ob.bettype
			FROM @Data AS b
				INNER JOIN bodb_Archive.dbo.bettrans_bk AS ob WITH (NOLOCK) ON ob.transid = b.RefNo
				LEFT JOIN @Data AS cb ON b.RefNo = cb.RefNo AND cb.BetType = 903
			WHERE b.BetType IN (901, 902) AND b.TableID = 3
		END

		-- Get more info for CashOut tickets
		IF EXISTS (SELECT TOP(1) 1 FROM @Data WHERE BetType = 911 AND TableID = 3)
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
			WHERE b.BetType = 911 AND b.TableID = 3
		END

		IF EXISTS (SELECT TOP(1) 1 FROM @Data WHERE BetType = 912 AND TableID = 3)
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
				INNER JOIN bodb_Archive.dbo.bettrans_bk AS cob WITH (NOLOCK) ON cob.transid = b.RefNo
				INNER JOIN bodb_Archive.dbo.bettrans_bk AS ob WITH (NOLOCK) ON ob.transid = cob.RefNo
				LEFT JOIN @Data AS cb ON cb.RefNo = b.RefNo AND cb.BetType = 913
			WHERE b.BetType = 912 AND b.TableID = 3
		END
	END
	
	IF EXISTS (SELECT 1 FROM @Data)
	BEGIN
		-- Get Sport/Bettype info
		UPDATE b
		SET
			Product = CASE
						WHEN s.EventType = 0 AND s.ProductID = 1 THEN 'Parlay'		-- Sportsbook Parlay
						WHEN s.EventType = 0 AND s.ProductID = 6 THEN 'OneRNG'		-- RNG Casino
						WHEN s.ProductID = 8 THEN 'Keno'
						WHEN s.EventType = 0 AND s.ProductID = 21 THEN 'AllBet'
						WHEN s.EventType = 0 AND s.ProductID = 22 THEN 'VB'			-- Macau Games
						WHEN s.EventType = 0 AND s.ProductID = 23 THEN 'NG2'
						WHEN s.EventType = 0 AND s.ProductID = 27 THEN 'ParlayVS2'	-- Betradar Virtual Sports Parlay
						WHEN s.EventType = 0 AND s.ProductID = 83 THEN 'ParlayVS4'	-- Virtual Sports 4 Parlay
						WHEN s.EventType = 0 AND s.ProductID = 88 THEN 'ParlayVS5'	-- Virtual Sports 5 Parlay
						WHEN s.ProductID = 25 THEN 'CO'								-- Cash Out
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
						WHEN s.ProductID = 48 THEN 'GPIRNG'							-- GPI
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
						WHEN s.ProductID = 80 THEN 'WE'								-- WE Live Casino
						WHEN s.ProductID = 84 THEN 'GPILT'							-- GPI Lottery
						WHEN s.ProductID = 85 THEN 'NS'								-- Nextspin
						WHEN s.ProductID = 86 THEN 'SNG'							-- Saba xD
						WHEN s.ProductID = 81 THEN 'SAC'							-- Saba Coins
						WHEN s.ProductID = 87 THEN 'FS'								-- FastSpin
						WHEN s.ProductID = 89 THEN 'FAC'							-- FA CHAI
						WHEN s.ProductID = 90 THEN 'GPILC'							-- GPI Live casino
						WHEN s.ProductID = 91 THEN 'PS'								-- PLAY STAR
						WHEN s.ProductID = 95 THEN 'HOT'							-- HOTDOG
						WHEN s.ProductID = 96 THEN 'ON'								-- ON Casino
						WHEN s.ProductID = 98 THEN 'WLC'							-- W Casino
						WHEN s.ProductID = 100 THEN 'PTRNG'							-- Playtech
						WHEN s.ProductID = 101 THEN 'PTLC'							-- Playtech Live Casino 
						WHEN s.ProductID = 102 THEN 'SBK'							-- SABA Keno
						WHEN s.ProductID = 103 THEN 'ASK'							-- ASKMESLOT
						WHEN s.ProductID = 104 THEN 'FG'							-- FunkyGames
						WHEN s.ProductID = 105 THEN 'ODG'							-- ODIN GAMING
						WHEN s.ProductID = 107 THEN 'MGLC'							-- Microgaming Live
						WHEN s.ProductID = 108 THEN 'RGRNG'							-- RichGaming
						WHEN s.EventType = 1 AND s.ProductID = 1 THEN 'SB'			-- Sportsbook
						WHEN s.EventType = 1 AND s.ProductID = 3 THEN 'NG'			-- Number Game
						WHEN s.EventType = 1 AND s.ProductID = 5 THEN 'VS'			-- Virtual Sports Sportsbook
						WHEN s.EventType = 1 AND s.ProductID = 27 THEN 'VS2'		-- Betradar Virtual Sports
						WHEN s.EventType = 2 AND s.ProductID = 1 THEN 'Outright'						
						WHEN s.EventType = 0 AND s.ProductID = 3 THEN 'H5LG'		-- Happy 5 Linked Games
						WHEN s.EventType = 1 AND s.ProductID = 83 THEN 'VS4'		-- Virtual Sports 4
						WHEN s.EventType = 3 AND s.ProductID = 27 THEN 'VS2Racing'	-- VS2 Racing
						WHEN s.EventType = 3 AND s.ProductID = 106 THEN 'VS7'		-- Virtual Sports 7 
						WHEN s.EventType = 5 AND s.ProductID = 88 THEN 'VS5'		-- Virtual Sports 5
						WHEN s.EventType = 5 AND s.ProductID = 71 THEN 'VS6'		-- VS6 Virtual Sports
						ELSE 'Unknown'
					END,
			IsCashOut = CASE
							WHEN b.betdaqid = -2 AND s.EventType = 1 AND s.ProductID = 1 AND ',' + @OriginalStatusIdList + ',' LIKE '%,88,%' THEN 1
							ELSE 0
						END,
			RefTable = s.RefTable,
			EventType = s.EventType,
			SubProduct = s.SubProduct
		FROM @Data AS b
			INNER JOIN @SportBettype AS s ON b.BetType = s.BetType

		DELETE @Data
		WHERE 
			Product IS NULL
			OR BetType IN (903, 904, 913, 914)
			OR (Product NOT IN ('SB', 'Parlay')
				AND (RefTable NOT IN (1,2)								
					OR WinLostDate < @Yesterday)
				AND ',' + @OriginalStatusIdList + ',' NOT LIKE '%,' + CONVERT(VARCHAR(3), StatusId) + ',%')
			OR (',' + @OriginalStatusIdList + ',' NOT LIKE '%,99,%'		-- Abnormal Bets
				AND Status = 'Void'
				AND ISNULL(CAST(('<xml>' + ExtraInfo + '</xml>') AS XML).value('data(/xml/p1/@ab)[1]','TINYINT'), 0) = 1
				AND IsCashOut = 0)
			OR (',' + @OriginalStatusIdList + ',' NOT LIKE '%,102,%'	-- Void
				AND Status = 'Void'
				AND ISNULL(CAST(('<xml>' + ExtraInfo + '</xml>') AS XML).value('data(/xml/p1/@ab)[1]','TINYINT'), 0) = 0
				AND IsCashOut = 0)
			OR (Status = 'Refund' AND IsCashOut = 0 AND ',' + @OriginalStatusIdList + ',' NOT LIKE '%,103,%')
		IF EXISTS (SELECT 1 FROM @Data WHERE Product = 'SB' AND Status IN ('Waiting', 'Running', 'Draw', 'Won', 'Lose'))
		BEGIN
			UPDATE b
			SET b.SettlementStatus = m.SettlementStatus
			FROM @Data AS b
				INNER JOIN dbo.match AS m WITH (NOLOCK) ON m.matchid = b.matchid
			WHERE b.Product = 'SB' AND b.Status IN ('Waiting', 'Running', 'Draw', 'Won', 'Lose')

			UPDATE b
			SET b.SettlementStatus = m.SettlementStatus
			FROM @Data AS b
				INNER JOIN dbo.match AS m WITH (NOLOCK) ON m.matchid = b.EventId
			WHERE b.TableID = 4
				AND b.BetType BETWEEN 801 AND 806
				AND b.Status IN ('Waiting', 'Running', 'Draw', 'Won', 'Lose')

			IF ',' + @OriginalStatusIdList + ',' NOT LIKE '%,0,%'	-- Not include Running
			BEGIN
				DELETE @Data
				WHERE Product = 'SB'
					AND Status = 'Running'
					AND (ISNULL(SecAcceptFlag, 0) <> 1 OR ISNULL(CheckTime, CURRENT_TIMESTAMP) <= CURRENT_TIMESTAMP)	-- not Waiting (Second Accept)
					AND ISNULL(SettlementStatus, 0) & 13 = 0															-- not Result Pending, Under Settlement
			END

			IF ',' + @OriginalStatusIdList + ',' NOT LIKE '%,1,%'	-- Not include Waiting
			BEGIN
				DELETE FROM @Data
				WHERE Product = 'SB'
					AND (Status = 'Waiting'
						OR (Status = 'Running'		-- Waiting (Second Accept)
							AND ISNULL(SecAcceptFlag, 0) = 1
							AND ISNULL(CheckTime, CURRENT_TIMESTAMP) > CURRENT_TIMESTAMP))
			END

			IF ',' + @OriginalStatusIdList + ',' NOT LIKE '%,111,%'		-- Not include Draw, Won, Lose
				OR ',' + @OriginalStatusIdList + ',' NOT LIKE '%,112,%'
				OR ',' + @OriginalStatusIdList + ',' NOT LIKE '%,113,%'
			BEGIN
				DELETE FROM @Data
				WHERE Product = 'SB'
					AND (ISNULL(SettlementStatus, 0) & 1 = 0		-- isPending flag (bit 1) = 0
						OR (Stake = 0								-- Cash Out All
							AND BetdaqId = 0
							AND ExtraInfo LIKE '%p25%')
						OR IsCashOut = 0)							-- New Cash Out
					AND ((Status = 'Draw' AND ',' + @OriginalStatusIdList + ',' NOT LIKE '%,111,%')
						OR (Status = 'Won' AND ',' + @OriginalStatusIdList + ',' NOT LIKE '%,112,%')
						OR (Status = 'Lose' AND ',' + @OriginalStatusIdList + ',' NOT LIKE '%,113,%'))
					AND IsCashOut = 0
			END

			IF ',' + @OriginalStatusIdList + ',' NOT LIKE '%,2,%'		-- Not include Delay Payout
			BEGIN
				DELETE @Data
				WHERE Product = 'SB'
					AND ISNULL(SettlementStatus, 0) & 1 <> 0		-- isPending flag (bit 1) = 1
					AND ((Status = 'Running'
							AND (ISNULL(SecAcceptFlag, 0) = 0 OR ISNULL(CheckTime, CURRENT_TIMESTAMP) <= CURRENT_TIMESTAMP))		-- not Waiting (Second Accept)
						OR Status IN ('Draw', 'Won', 'Lose'))
					AND (Stake <> 0									-- Not Cash Out All
						OR BetdaqId <> 0
						OR ExtraInfo NOT LIKE '%p25%')
					AND IsCashOut = 0
			END

			IF ',' + @OriginalStatusIdList + ',' NOT LIKE '%,3,%'	-- Not include Under Settlement
			BEGIN
				DELETE @Data
				WHERE Product = 'SB'
					AND Status = 'Running'
					AND (ISNULL(SecAcceptFlag, 0) = 0 OR ISNULL(CheckTime, CURRENT_TIMESTAMP) <= CURRENT_TIMESTAMP)			-- not Waiting (Second Accept)
					AND ISNULL(SettlementStatus, 0) & 12 <> 0	-- isUnderSettlement flag (bit 3) = 1 OR isSystemSettlement flag (bit 4) = 1
					AND ISNULL(SettlementStatus, 0) & 1 = 0		-- isPending flag (bit 1) = 0
					AND IsCashOut = 0
			END
		END

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
					AWinLost		MONEY,
					MWinLost		MONEY,
					SWinLost		MONEY,
					Commission		MONEY,
					Comm			MONEY,
					AComm			MONEY,
					SComm			MONEY
				)

				-- Prepare temp table
				INSERT INTO @RefCodeTmp
				SELECT
					RefCode,
					MIN(TransId) AS TransId,
					SUM(Stake) AS Stake,
					SUM(Actual_Stake) AS Actual_Stake,
					SUM(WinLost) AS WinLost,
					SUM(AWinLost) AS AWinLost,
					SUM(MWinLost) AS MWinLost,
					SUM(SWinLost) AS SWinLost,
					SUM(Commission) AS Commission,
					SUM(Comm) AS Comm,
					SUM(AComm) AS AComm,
					SUM(SComm) AS SComm
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
						b.AWinLost = r.AWinLost,
						b.MWinLost = r.MWinLost,
						b.SWinLost = r.SWinLost,
						b.Commission = r.Commission,
						b.Comm = r.Comm,
						b.AComm = r.AComm,
						b.SComm = r.SComm,
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

			IF @ExcludeBettrans = 0
			BEGIN
				-- Get yesterday and today running and settled bettransRnG/bettransLC tickets
				IF EXISTS ( SELECT 1 FROM @Data
						WHERE (Product IN ('VB', 'PP', 'OneRNG', 'CC', 'SG', 'SBC', 'RNGW', 'PGS', 'JK', 'MXG', 'HB', 'CG', 'VGA', 'AP', 'APM', 'SEA', 'MGRNG', 'JIG', 'L22', 'UUSL', 'SNG') -- bettransRnG
									OR RefTable = 1)
						AND WinLostDate >= @Yesterday)
				BEGIN
					-- Running
					IF ',' + @OriginalStatusIdList + ',' LIKE '%,0,%'
					BEGIN
						INSERT INTO @TmpData
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
							0 AS Commission,
							0 AS Comm,
							0 AS AComm,
							0 AS SComm,
							AVG(brng.apositiontaking) AS apositiontaking,
							AVG(brng.mpositiontaking) AS mpositiontaking,
							AVG(brng.spositiontaking) AS spositiontaking,
							AVG(brng.playerdiscount) AS playerdiscount,
							CASE
								WHEN brng.recommend IN (-3, -4) THEN 0
								ELSE AVG(brng.discount)
							END AS discount,
							CASE
								WHEN brng.mrecommend = -4 THEN 0
								ELSE AVG(brng.adiscount)
							END AS adiscount,
							AVG(brng.sdiscount) AS sdiscount,
							0 AS OddsSpread
						FROM @Data AS c
							INNER JOIN dbo.bettransRnG AS brng WITH (NOLOCK) ON brng.RefNo = c.TransId
					WHERE (c.Product IN ('VB', 'PP', 'OneRNG', 'CC', 'SG', 'SBC', 'RNGW', 'PGS', 'JK', 'MXG', 'HB', 'CG', 'VGA', 'AP', 'APM', 'SEA', 'MGRNG', 'JIG', 'L22', 'UUSL', 'SNG')
								OR c.RefTable = 1)
							AND c.WinLostDate >= @Yesterday
							AND brng.statusID IN (0, 1)
						GROUP BY
							c.TransId,
							c.Product,
							brng.recommend,
							brng.mrecommend
					END

					-- Settled
					IF ',' + @OriginalStatusIdList + ',' LIKE '%,111,%'
						OR ',' + @OriginalStatusIdList + ',' LIKE '%,112,%'
						OR ',' + @OriginalStatusIdList + ',' LIKE '%,113,%'
					BEGIN
						INSERT INTO @TmpData
						SELECT
							c.TransId AS RefNo,
							CASE
								WHEN c.SubProduct LIKE 'Jackpot%' THEN ISNULL(AVG(CASE WHEN brng.statusID IN (111, 112, 113) THEN brng.ContributionRate END), 0)
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
							SUM(brng.playercomm) AS Commission,
							SUM(brng.comm - brng.playercomm) AS Comm,
							SUM(brng.acomm - brng.comm) AS AComm,
							SUM(brng.scomm - brng.acomm) AS SComm,
							AVG(brng.apositiontaking) AS apositiontaking,
							AVG(brng.mpositiontaking) AS mpositiontaking,
							AVG(brng.spositiontaking) AS spositiontaking,
							AVG(brng.playerdiscount) AS playerdiscount,
							CASE
								WHEN brng.recommend IN (-3, -4) THEN 0
								ELSE AVG(brng.discount)
							END AS discount,
							CASE
								WHEN brng.mrecommend = -4 THEN 0
								ELSE AVG(brng.adiscount)
							END AS adiscount,
							AVG(brng.sdiscount) AS sdiscount,
							CASE
								WHEN c.SubProduct LIKE 'Jackpot%' THEN ISNULL(SUM(brng.BetStake), 0)
								ELSE 0
							END AS OddsSpread
						FROM @Data AS c
							INNER JOIN dbo.bettransRnG AS brng WITH (NOLOCK) ON brng.RefNo = c.TransId
					WHERE (c.Product IN ('VB', 'PP', 'OneRNG', 'CC', 'SG', 'SBC', 'RNGW', 'PGS', 'JK', 'MXG', 'HB', 'CG', 'VGA', 'AP', 'APM', 'SEA', 'MGRNG', 'JIG', 'L22', 'UUSL', 'SNG')
								OR c.RefTable = 1)
							AND c.WinLostDate >= @Yesterday
							AND brng.statusID NOT IN (0, 1)
						GROUP BY
							c.TransId,
							c.Product,
							c.SubProduct,
							brng.recommend,
							brng.mrecommend
					END
				END

				IF EXISTS (SELECT 1 FROM @Data WHERE (Product IN ('Allbet', 'SAG', 'SXG', 'IBCLC', 'ION', 'WM', 'BG', 'PPL', 'FGGL', 'YB', 'WE') OR RefTable = 2) AND WinLostDate >= @Yesterday)		-- bettransLC
				BEGIN
					-- Running
					IF ',' + @OriginalStatusIdList + ',' LIKE '%,0,%'
					BEGIN
						INSERT INTO @TmpData
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
							0 AS Commission,
							0 AS Comm,
							0 AS AComm,
							0 AS SComm,
							AVG(blc.apositiontaking) AS apositiontaking,
							AVG(blc.mpositiontaking) AS mpositiontaking,
							AVG(blc.spositiontaking) AS spositiontaking,
							AVG(blc.playerdiscount) AS playerdiscount,
							CASE
								WHEN blc.recommend IN (-3, -4) THEN 0
								ELSE AVG(blc.discount)
							END AS discount,
							CASE
								WHEN blc.mrecommend = -4 THEN 0
								ELSE AVG(blc.adiscount)
							END AS adiscount,
							AVG(blc.sdiscount) AS sdiscount,
							0 AS OddsSpread
						FROM @Data AS c
							INNER JOIN dbo.bettransLC AS blc WITH (NOLOCK) ON blc.RefNo = c.TransId
						WHERE (c.Product IN ('Allbet', 'SAG', 'SXG', 'IBCLC', 'ION', 'WM', 'BG', 'PPL', 'FGGL', 'YB', 'WE') OR c.RefTable = 2)
							AND c.WinLostDate >= @Yesterday
							AND blc.statusID IN (0, 1)
						GROUP BY
							c.TransId,
							c.Product,
							blc.recommend,
							blc.mrecommend
					END

					-- Settled
					IF ',' + @OriginalStatusIdList + ',' LIKE '%,111,%'
						OR ',' + @OriginalStatusIdList + ',' LIKE '%,112,%'
						OR ',' + @OriginalStatusIdList + ',' LIKE '%,113,%'
					BEGIN
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
							SUM(blc.awinlost) AS AWinLost,
							SUM(blc.mwinlost) AS MWinLost,
							SUM(blc.swinlost) AS SWinLost,
							SUM(blc.playercomm) AS Commission,
							SUM(blc.comm - blc.playercomm) AS Comm,
							SUM(blc.acomm - blc.comm) AS AComm,
							SUM(blc.scomm - blc.acomm) AS SComm,
							AVG(blc.apositiontaking) AS apositiontaking,
							AVG(blc.mpositiontaking) AS mpositiontaking,
							AVG(blc.spositiontaking) AS spositiontaking,
							AVG(blc.playerdiscount) AS playerdiscount,
							CASE
								WHEN blc.recommend IN (-3, -4) THEN 0
								ELSE AVG(blc.discount)
							END AS discount,
							CASE
								WHEN blc.mrecommend = -4 THEN 0
								ELSE AVG(blc.adiscount)
							END AS adiscount,
							AVG(blc.sdiscount) AS sdiscount,
							CASE
								WHEN SubProduct LIKE 'Jackpot%' THEN ISNULL(SUM(blc.BetStake), 0)
								ELSE 0
							END AS OddsSpread
						FROM @Data AS c
							INNER JOIN dbo.bettransLC AS blc WITH (NOLOCK) ON blc.RefNo = c.TransId
						WHERE (c.Product IN ('Allbet', 'SAG', 'SXG', 'IBCLC', 'ION', 'WM', 'BG', 'PPL', 'FGGL', 'YB', 'WE') OR c.RefTable = 2)
							AND c.WinLostDate >= @Yesterday
							AND blc.statusID NOT IN (0, 1)
						GROUP BY
							c.TransId,
							c.Product,
							blc.recommend,
							blc.mrecommend,
							c.SubProduct
					END
				END

				DELETE FROM @TmpData
				WHERE (Status = 'Draw' AND ',' + @OriginalStatusIdList + ',' NOT LIKE '%,111,%')
					OR (Status = 'Won' AND ',' + @OriginalStatusIdList + ',' NOT LIKE '%,112,%')
					OR (Status = 'Lose' AND ',' + @OriginalStatusIdList + ',' NOT LIKE '%,113,%')

				DELETE b
				FROM @Data AS b
				WHERE (b.Product IN ('VB', 'PP', 'OneRNG', 'CC', 'SG', 'SBC', 'RNGW', 'PGS', 'JK', 'MXG', 'HB', 'CG', 'AP', 'APM', 'SEA', 'MGRNG', 'JIG', 'L22', 'SNG', 'Allbet', 'SAG', 'SXG', 
						'IBCLC', 'ION', 'WM', 'BG', 'PPL', 'VGA', 'FGGL', 'YB', 'WE', 'UUSL')
							OR b.RefTable IN  (1,2))
					AND b.Winlostdate >= @Yesterday
					AND NOT EXISTS (SELECT 1 FROM @TmpData WHERE RefNo = b.TransId)
			END

			-- bettrans range
			IF EXISTS (SELECT TOP(1) 1 FROM @Data WHERE TableID IN (1, 4))
			BEGIN
				UPDATE b
				SET
					TransId = CASE
								WHEN b.Product = 'Parlay' AND b.bettype = 29 AND ISNULL(b.betid, 0) > 0 THEN b.betid
								ELSE b.transid
							END,
					SportType = CASE
									WHEN b.Product IN ('OneRNG', 'CC', 'NPHP', 'SG', 'VRG', 'SAG', 'TG', 'SBC', 'I4D', 'SXG', 'IBCLC', 'BBIN', 'ION', 'PGS', 
										'JK', 'RNGW', 'WM', 'VS3', 'BG', 'H5LG', 'MXG', 'SLT', 'PPL', 'HB', 'CG', 'VGA', 'AP', 'APM', 'FGGL', 'SEA', 'MGRNG', 
										'TIP', 'JIG', 'YB', 'WE', 'L22', 'UUSL', 'SAC', 'SNG') THEN b.matchid
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
									WHEN b.EventType = 3 THEN vr.SportType
									WHEN b.EventType = 5 THEN m3rd.sporttype
									WHEN b.RefTable IN (1, 2) THEN b.matchid
									WHEN b.EventType = 5 THEN m3rd.sporttype
									ELSE 0
								END,
					BetTeam = CASE
									WHEN b.Product IN ('SB', 'CO', 'NG', 'VS', 'VS2', 'Parlay', 'ParlayVS2', 'BTC', 'LG', 'ParlayVS4', 'VS4', 'VS5', 'ParlayVS5', 'VS6') THEN b.betteam
									WHEN b.EventType = 3 THEN b.betteam
									ELSE ''
								END,
					Hdp1 = CASE
								WHEN b.Product IN ('SB', 'CO', 'NG', 'VS', 'VS2', 'Parlay', 'ParlayVS2', 'NG2', 'BTC', 'LG', 'ParlayVS4', 'VS5', 'ParlayVS5', 'VS6') THEN b.hdp1
								ELSE 0
							END,
					Hdp2 = CASE
								WHEN b.Product IN ('SB', 'CO', 'VS', 'VS2', 'Parlay', 'ParlayVS2', 'NG2', 'LG', 'ParlayVS4', 'VS5', 'ParlayVS5', 'VS6') THEN b.hdp2
								ELSE 0
							END,
					OddsType = CASE
									WHEN b.Product IN ('SB', 'Outright', 'CO', 'NG', 'VS', 'VS2', 'LG', 'VS4', 'VS5', 'VS6') THEN b.oddstype
									ELSE 0
								END,
					Odds = CASE
								WHEN b.Product IN ('SB', 'CO', 'NG', 'VS', 'VS2', 'Outright', 'Parlay', 'OneRNG', 'Keno', 'NG2', 'ParlayVS2', 
									'Lottery', 'VRG', 'TG', 'I4D', 'PP', 'SG', 'VS3', 'SBC', 'H5LG', 'SLT', 'VGA', 'BTC', 'LG', 'ParlayVS4', 'VS4', 'VS6') THEN b.odds
								WHEN b.SubProduct LIKE 'Jackpot%' THEN b.odds
								WHEN b.EventType IN (3, 5) THEN b.odds
								ELSE 0
							END,
					MOdds = CASE
								WHEN b.Product IN ('SB', 'CO', 'NG', 'VS', 'VS2', 'Outright', 'Parlay', 'ParlayVS2', 'LG', 'VS4', 'ParlayVS4', 'VS5', 'ParlayVS5', 'VS6') THEN b.modds
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
								WHEN @IsCN88 = 1 AND b.Product IN ('SB', 'VS', 'VS2') AND b.status = 'Won' AND b.modds = 0.25 THEN 'Half Won'
								WHEN @IsCN88 = 1 AND b.Product IN ('SB', 'VS', 'VS2') AND b.status = 'Lose' AND b.modds = -0.25 THEN 'Half Lose'
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
										WHEN b.Product IN ('SB', 'CO', 'NG', 'VS', 'VS2', 'LG', 'VS5', 'VS6') THEN b.liveindicator
										ELSE 0
									END,
					LiveHomeScore = CASE
										WHEN b.Product IN ('SB', 'CO', 'NG', 'VS', 'VS2', 'Outright', 'NG2', 'LG', 'VS5') THEN b.livehomescore
										ELSE 0
									END,
					LiveAwayScore = CASE
										WHEN b.Product IN ('SB', 'CO', 'NG', 'VS', 'VS2', 'Outright', 'LG', 'VS5') THEN b.liveawayscore
										ELSE 0
									END,
					LeagueId = CASE
									WHEN b.Product IN ('SB', 'CO', 'NG', 'VS', 'VS2', 'LG', 'VS4') THEN m.leagueid
									WHEN b.Product IN ('Outright') THEN o.leagueid
									WHEN b.EventType = 3 THEN vr.LeagueID
									WHEN b.EventType = 5 THEN m3rd.League3rdId
									ELSE 0
								END,
					MatchId = CASE
									WHEN b.Product IN ('NG2') THEN b.betdaqid
									WHEN b.Product IN ('SB', 'CO', 'NG', 'VS', 'VS2', 'LG', 'VS4') THEN m.matchid
									WHEN b.Product IN ('Outright') THEN o.orid
									WHEN b.Product IN ('BTC') THEN b.matchid
									WHEN b.EventType IN (3, 5) THEN b.matchid
									WHEN b.Product = 'TIP' THEN ISNULL(CAST(('<xml>' + b.ExtraInfo + '</xml>') AS XML).value('data(/xml/p74/@m)[1]','INT'), 0)
									ELSE 0
								END,
					MatchCode = CASE
									WHEN b.Product IN ('SB', 'CO', 'NG', 'VS', 'VS2', 'LG', 'VS4') THEN m.matchcode
									WHEN b.Product IN ('Outright') THEN o.matchcode
									WHEN b.Product IN ('VS5') THEN m3rd.MatchCode
									ELSE ''
								END,
					Race = CASE
								WHEN b.Product IN ('Outright') THEN o.groupmatch
								ELSE ''
							END,
					EventDate = CASE
									WHEN b.Product IN ('SB', 'CO') THEN m.GlobalShowTime
									WHEN b.Product IN ('NG', 'VS', 'VS2', 'LG', 'VS4') THEN m.eventdate
									WHEN b.Product IN ('Outright') THEN o.eventdate
									WHEN b.Product IN ('BTC') THEN m3rd.EndTime
									ELSE b.winlostdate
								END,
					HomeId = CASE
								WHEN b.Product IN ('SB', 'CO', 'NG', 'VS', 'VS2', 'LG', 'VS4') THEN m.homeid
								WHEN b.Product IN ('Outright') THEN o.teamid
								WHEN b.EventType = 5 THEN m3rd.HomeId
								ELSE 0
							END,
					AwayId = CASE
								WHEN b.Product IN ('SB', 'CO', 'NG', 'VS', 'VS2', 'LG', 'VS4') THEN m.awayid
								WHEN b.EventType = 5 THEN m3rd.AwayId
								ELSE 0
							END,
					IsNeutral = CASE
									WHEN b.Product IN ('SB', 'CO', 'NG', 'VS', 'VS2', 'LG') THEN ISNULL(m.IsNeutral, 0)
									ELSE 0
								END,
					ShowTime = CASE
									WHEN b.Product IN ('VS', 'VS2', 'LG', 'VS4') THEN CONVERT(NVARCHAR(50), m.kickofftime)
									WHEN b.Product IN ('SB', 'NG') THEN ISNULL(m.showtime, '')
									WHEN b.EventType = 5 THEN CONVERT(NVARCHAR(50), m3rd.StartTime)
									ELSE ''
								END,
					BetCheck = CASE
									WHEN b.Product IN ('SB', 'CO', 'Parlay', 'ParlayVS2', 'VRG', 'H5LG', 'SLT', 'ParlayVS4', 'ParlayVS5') THEN ISNULL(b.betcheck, '')
									WHEN b.Product IN ('Keno') THEN ISNULL(b.comstatus, '')
									ELSE ''
								END,
					ComStatus = CASE WHEN b.comstatus = '1' THEN '1' ELSE '0' END,
					TransDesc = CASE
									WHEN b.Product IN ('SB', 'CO', 'VS2', 'OneRNG', 'CC', 'SG', 'Keno', 'VB', 'NG2', 'Lottery', 
										'PP', 'TG', 'VRG', 'I4D', 'PGS', 'JK', 'VS3', 'H5LG', 'SLT', 'HB', 'CG', 'AP', 'APM', 'SEA', 'LG', 'VS4', 'VS5') THEN ISNULL(b.transdesc, '')
									WHEN b.EventType = 3 THEN ISNULL(b.transdesc, '')
									ELSE ''
								END,
					OddsSpread = CASE
									WHEN b.Product IN ('SB', 'CO', 'OneRNG', 'PP', 'SG', 'SBC', 'VGA', 'Parlay') THEN ISNULL(b.oddsspread, 0)
									WHEN b.SubProduct LIKE 'Jackpot%' THEN ISNULL(b.oddsspread, 0)
									ElSE 0
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
					Discount = CASE
									WHEN bt.recommend IN (-3, -4) THEN 0
									ELSE b.discount
								END,
					ADiscount = CASE
									WHEN bt.mrecommend = -4 THEN 0
									ELSE b.adiscount
								END
				FROM @Data AS b
					LEFT JOIN dbo.match AS m WITH (NOLOCK) ON b.Product IN ('SB', 'CO', 'NG', 'VS', 'VS2', 'LG', 'VS4') AND b.matchid = m.matchid
					LEFT JOIN dbo.outright AS o WITH (NOLOCK) ON b.Product IN ('Outright') AND b.matchid = o.orid
					LEFT JOIN dbo.League AS l WITH (NOLOCK) ON b.Product IN ('Outright') AND o.leagueid = l.leagueid
					LEFT JOIN dbo.VSRaceInfo AS vr WITH (NOLOCK) ON b.EventType = 3 AND vr.EventID = b.matchid
					LEFT JOIN dbo.match3rd AS m3rd WITH (NOLOCK) ON b.EventType = 5 AND b.matchid = m3rd.match3rdid
					LEFT JOIN dbo.bettrans AS bt WITH(NOLOCK) ON bt.TransId = b.TransId
				WHERE b.TableID = 1
					AND (b.RefTable NOT IN (1,2)
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
					WHERE b.Product = 'TIP'
						AND b.TableID = 1
				END

				-- translog
				UPDATE b
				SET SportType = CASE
									WHEN b.BetType BETWEEN 801 AND 806 THEN m.sporttype
									WHEN b.Product = 'Keno' THEN 202
									WHEN b.Product = 'Lottery' THEN 220		-- Lottery
									WHEN b.Product IN ('VRG', 'TG', 'I4D', 'VS3', 'H5LG', 'SLT') THEN b.ProductId	-- Virtual Games, Indo 4D
									ELSE 0
								END,
					BetId = 0,
					BetTeam = '',
					Hdp1 = 0,
					Hdp2 = 0,
					OddsType = CASE
									WHEN b.BetType BETWEEN 801 AND 806 THEN CONVERT(TINYINT, ISNULL(b.custom1, 0))
									ELSE 0
								END,
					Odds = CASE
								WHEN b.BetType BETWEEN 801 AND 806 THEN b.Odds
								WHEN b.Product IN ('Keno', 'Lottery', 'VRG', 'TG', 'I4D', 'VS3', 'H5LG', 'SLT') THEN b.Odds
								ELSE 0
							END,
					OddsId = 0,
					MOdds = 0,
					SettlementStatus = CASE
											WHEN b.BetType BETWEEN 801 AND 806 THEN ISNULL(m.SettlementStatus, 0)
											ELSE 0
										END,
					WinLost = 0,
					AWinLost = 0,
					MWinLost = 0,
					SWinLost = 0,
					Commission = 0,
					Comm = 0,
					AComm = 0,
					SComm = 0,
					LiveIndicator = 0,
					LiveHomeScore = 0,
					LiveAwayScore = 0,
					LeagueId = CASE
									WHEN b.BetType BETWEEN 801 AND 806 THEN m.leagueid
									ELSE 0
								END,
					MatchId = CASE
									WHEN b.BetType BETWEEN 801 AND 806 THEN m.matchid
									ELSE 0
								END,
					MatchCode = CASE
									WHEN b.BetType BETWEEN 801 AND 806 THEN m.matchcode
									ELSE ''
								END,
					Race = '',
					EventDate = CASE
									WHEN b.BetType BETWEEN 801 AND 806 THEN m.GlobalShowTime
									ELSE b.winlostdate
								END,
					HomeId = CASE
								WHEN b.BetType BETWEEN 801 AND 806 THEN m.homeid
								ELSE 0
							END,
					AwayId = CASE
								WHEN b.BetType BETWEEN 801 AND 806 THEN m.awayid
								ELSE 0
							END,
					IsNeutral = CASE
									WHEN b.BetType BETWEEN 801 AND 806 THEN ISNULL(m.IsNeutral, 0)
									ELSE 0
								END,
					ShowTime = CASE
									WHEN b.BetType BETWEEN 801 AND 806 THEN ISNULL(m.showtime, '')
									ELSE ''
								END,
					BetCheck = CASE
									WHEN b.Product IN ('H5LG') THEN b.Gameid3rd
									WHEN b.Product IN ('VRG', 'SLT') THEN b.TranId3rd
									WHEN b.Product IN ('Keno') THEN ISNULL(b.custom2, '')
									WHEN b.Product IN ('VS3') THEN ISNULL(b.custom1, '')
									ELSE ''
								END,
					ComStatus = 0,
					TransDesc = CASE
									WHEN b.BetType BETWEEN 801 AND 806 THEN b.transdesc
									WHEN b.Product IN ('Keno', 'Lottery', 'VRG', 'TG', 'I4D', 'VS3', 'H5LG', 'SLT') THEN b.transdesc
									ELSE ''
								END,
					OddsSpread = 0,
					BetdaqId = -1,
					ExtraInfo = ISNULL(b.ExtraInfo, ''),
					Discount = CASE
									WHEN tl.recommend IN (-3, -4) THEN 0
									ELSE b.discount
								END,
					ADiscount = CASE
									WHEN tl.mrecommend = -4 THEN 0
									ELSE b.adiscount
								END
				FROM @Data AS b
					LEFT JOIN dbo.match AS m WITH (NOLOCK) ON b.BetType BETWEEN 801 AND 806 AND b.eventid = m.matchid
					LEFT JOIN dbo.translog AS tl WITH (NOLOCK) ON tl.translogid = b.transid
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
					AWinLost			MONEY,
					MWinLost			MONEY,
					SWinLost			MONEY,
					Commission			MONEY,
					Comm				MONEY,
					AComm				MONEY,
					SComm				MONEY,
					APositionTaking		SMALLMONEY,
					MPositionTaking		SMALLMONEY,
					SPositionTaking		SMALLMONEY,
					PlayerDiscount		SMALLMONEY,
					Discount			SMALLMONEY,
					ADiscount			SMALLMONEY,
					SDiscount			SMALLMONEY,
					Status				NVARCHAR(10),
					StatusId			TINYINT,
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
					ISCashOut			TINYINT,
					CurrencyId			SMALLINT,
					SiteId				VARCHAR(20),
					DeviceType			TINYINT,
					RefTable			TINYINT,
					EventType			TINYINT,
					Subproduct			NVARCHAR(50)
				)

				INSERT INTO @TmpCasinoData
				SELECT
					b.TransId,
					b.RefNo,
					b.CustId,
					b.Creator,
					b.Currency,
					CASE
						WHEN b.Product IN ('OneRNG', 'CC', 'SG', 'SAG', 'SBC', 'SXG', 'IBCLC', 'ION', 'PGS', 'JK', 'RNGW', 'WM', 'BG', 'MXG', 'PPL', 'HB', 'CG', 'VGA', 'AP', 'APM', 'FGGL', 'SEA', 'MGRNG', 'JIG', 'YB', 'WE', 'L22', 'UUSL', 'SNG') THEN b.matchid
						WHEN b.Product = 'AllBet' THEN 211 -- AllBet
						WHEN b.Product = 'VB' THEN 212 -- Macau Games
						WHEN b.Product = 'PP' THEN 248 -- Pragmatic Casino
						WHEN b.RefTable IN (1, 2) THEN b.matchid
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
						WHEN b.SubProduct LIKE 'Jackpot%' THEN x.OddsSpread
						ELSE 0
					END AS OddsSpread,
					x.Stake,
					x.Actual_Stake,
					x.WinLost,
					x.AWinLost,
					x.MWinLost,
					x.SWinLost,
					x.Commission,
					x.Comm,
					x.AComm,
					x.SComm,
					x.APositionTaking,
					x.MPositionTaking,
					x.SPositionTaking,
					x.PlayerDiscount,
					x.Discount,
					x.ADiscount,
					x.SDiscount,
					x.Status,
					0 AS StatusId,
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
						WHEN b.Product IN ('OneRNG', 'VB', 'PP', 'CC', 'SG', 'PGS', 'JK', 'HB', 'CG', 'AP', 'APM', 'SEA') THEN b.transdesc
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
					0,
					b.CurrencyId,
					b.SiteId,
					b.DeviceType,
					b.RefTable,
					b.EventType,
					b.Subproduct
				FROM @Data AS b
					INNER JOIN @TmpData AS x ON x.RefNo = b.TransId
				WHERE (b.Product IN ('VB', 'PP', 'OneRNG', 'CC', 'SG', 'SBC', 'RNGW', 'MXG', 'HB', 'CG', 'VGA', 'AP', 'APM', 'SEA', 'MGRNG', 'JIG', 'L22', 'SNG', 'Allbet', 'SAG', 'SXG', 'IBCLC', 'ION', 
						'PGS', 'JK', 'WM', 'BG', 'PPL', 'FGGL', 'YB', 'WE', 'UUSL')
							OR b.RefTable IN (1, 2))
					AND b.WinLostDate >= @Yesterday

				DELETE FROM @Data
				WHERE (Product IN ('VB', 'PP', 'OneRNG', 'CC', 'SG', 'SBC', 'RNGW', 'MXG', 'HB', 'CG', 'VGA', 'AP', 'APM', 'SEA', 'MGRNG', 'JIG', 'L22', 'SNG', 'Allbet', 'SAG', 'SXG', 'IBCLC', 'ION', 
						'PGS', 'JK', 'WM', 'BG', 'PPL', 'FGGL', 'YB', 'WE', 'UUSL')
							OR RefTable IN (1, 2))
					AND WinLostDate >= @Yesterday

				INSERT INTO @Data
				SELECT * FROM @TmpCasinoData
			END

			-- bettrans14 range
			IF EXISTS (SELECT TOP(1) 1 FROM @Data WHERE TableID = 2)
			BEGIN
				UPDATE b
				SET
					TransId = CASE
								WHEN b.Product = 'Parlay' AND b.bettype = 29 AND ISNULL(b.betid, 0) > 0 THEN b.betid
								ELSE b.transid
							END,
					SportType = CASE
									WHEN b.Product IN ('OneRNG', 'CC', 'NPHP', 'SG', 'VRG', 'SAG', 'TG', 'SBC', 'I4D', 'SXG', 'IBCLC', 'BBIN', 'ION', 'PGS', 
										'JK', 'RNGW', 'WM', 'VS3', 'BG', 'H5LG', 'MXG', 'SLT', 'PPL', 'HB', 'CG', 'VGA', 'AP', 'APM', 'FGGL', 'SEA', 'MGRNG', 
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
									WHEN b.EventType = 3 THEN vr.SportType
									WHEN b.EventType = 5 THEN m3rd.sporttype
									WHEN b.RefTable IN (1, 2) THEN b.matchid
									WHEN b.EventType = 5 THEN m3rd.sporttype
									ELSE 0
								END,
					BetTeam = CASE
									WHEN b.Product IN ('SB', 'CO', 'NG', 'VS', 'VS2', 'Parlay', 'ParlayVS2', 'BTC', 'LG', 'VS4', 'ParlayVS4', 'VS5', 'ParlayVS5', 'VS6') THEN b.betteam
									WHEN b.EventType = 3 THEN b.betteam
									ELSE ''
								END,
					Hdp1 = CASE
								WHEN b.Product IN ('SB', 'CO', 'NG', 'VS', 'VS2', 'Parlay', 'ParlayVS2', 'NG2', 'BTC', 'LG', 'VS4', 'ParlayVS4', 'VS5', 'ParlayVS5', 'VS6') THEN b.hdp1
								ELSE 0
							END,
					Hdp2 = CASE
								WHEN b.Product IN ('SB', 'CO', 'VS', 'VS2', 'Parlay', 'ParlayVS2', 'NG2', 'LG', 'VS4', 'ParlayVS4', 'VS5', 'ParlayVS5', 'VS6') THEN b.hdp2
								ELSE 0
							END,
					OddsType = CASE
									WHEN b.Product IN ('SB', 'Outright', 'CO', 'NG', 'VS', 'VS2', 'LG', 'VS4', 'ParlayVS4', 'VS5', 'ParlayVS5', 'VS6') THEN b.oddstype
									ELSE 0
								END,
					Odds = CASE
								WHEN b.Product IN ('SB', 'CO', 'NG', 'VS', 'VS2', 'Outright', 'Parlay', 'OneRNG', 'Keno', 'NG2', 'ParlayVS2', 
									'Lottery', 'VRG', 'TG', 'I4D', 'PP', 'SG', 'VS3', 'SBC', 'H5LG', 'SLT', 'VGA', 'BTC', 'LG', 'VS4', 'ParlayVS4', 'VS6') THEN b.odds
								WHEN b.SubProduct LIKE 'Jackpot%' THEN b.odds
								WHEN b.EventType IN (3, 5) THEN b.odds
								ELSE 0
							END,
					MOdds = CASE
								WHEN b.Product IN ('SB', 'CO', 'NG', 'VS', 'VS2', 'Outright', 'Parlay', 'ParlayVS2', 'LG', 'VS4', 'ParlayVS4', 'VS5', 'ParlayVS5', 'VS6') THEN b.modds
								ELSE 0
							END,
					Status = CASE
								WHEN @IsCN88 = 1 AND b.Product IN ('SB', 'VS', 'VS2') AND b.status = 'Won' AND b.modds = 0.25 THEN 'Half Won'
								WHEN @IsCN88 = 1 AND b.Product IN ('SB', 'VS', 'VS2') AND b.status = 'Lose' AND b.modds = -0.25 THEN 'Half Lose'
								WHEN b.Product = 'TG' AND b.status = 'Won' AND b.modds = 0.25 THEN 'Half Won'
								WHEN b.Product = 'TG' AND b.status = 'Lose' AND b.modds = -0.25 THEN 'Half Lose'
								ELSE b.status
							END,
					SettlementStatus = 0,
					WinLost = b.winlost - b.actual_stake,
					LiveIndicator = CASE
										WHEN b.Product IN ('SB', 'CO', 'NG', 'VS', 'VS2', 'LG', 'VS5', 'VS6') THEN b.liveindicator
										ELSE 0
									END,
					LiveHomeScore = CASE
										WHEN b.Product IN ('SB', 'CO', 'NG', 'VS', 'VS2', 'Outright', 'NG2', 'LG', 'VS5') THEN b.livehomescore
										ELSE 0
									END,
					LiveAwayScore = CASE
										WHEN b.Product IN ('SB', 'CO', 'NG', 'VS', 'VS2', 'Outright', 'LG', 'VS5') THEN b.liveawayscore
										ELSE 0
									END,
					LeagueId = CASE
									WHEN b.Product IN ('SB', 'CO', 'NG', 'VS', 'VS2', 'LG', 'VS4') THEN m.leagueid
									WHEN b.Product IN ('Outright') THEN o.leagueid
									WHEN b.EventType = 3 THEN vr.LeagueID
									WHEN b.EventType = 5 THEN m3rd.League3rdId
									ELSE 0
								END,
					MatchId = CASE
									WHEN b.Product IN ('NG2') THEN b.betdaqid
									WHEN b.Product IN ('SB', 'CO', 'NG', 'VS', 'VS2', 'LG', 'VS4') THEN m.matchid
									WHEN b.Product IN ('Outright') THEN o.orid
									WHEN b.EventType IN (3, 5) THEN b.matchid
									WHEN b.Product = 'TIP' THEN ISNULL(CAST(('<xml>' + b.ExtraInfo + '</xml>') AS XML).value('data(/xml/p74/@m)[1]','INT'), 0)
									ELSE 0
								END,
					MatchCode = CASE
									WHEN b.Product IN ('SB', 'CO', 'NG', 'VS', 'VS2', 'LG', 'VS4') THEN m.matchcode
									WHEN b.Product IN ('Outright') THEN o.matchcode
									WHEN b.Product IN ('VS5') THEN m3rd.MatchCode
									ELSE ''
								END,
					Race = CASE
								WHEN b.Product IN ('Outright') THEN o.groupmatch
								ELSE ''
							END,
					EventDate = CASE
									WHEN b.Product IN ('SB', 'CO') THEN m.GlobalShowTime
									WHEN b.Product IN ('NG', 'VS', 'VS2', 'LG', 'VS4') THEN m.eventdate
									WHEN b.Product IN ('Outright') THEN o.eventdate
									WHEN b.Product IN ('BTC') THEN m3rd.EndTime
									ELSE b.winlostdate
								END,
					HomeId = CASE
								WHEN b.Product IN ('SB', 'CO', 'NG', 'VS', 'VS2', 'LG', 'VS4') THEN m.homeid
								WHEN b.Product IN ('Outright') THEN o.teamid
								WHEN b.EventType = 5 THEN m3rd.HomeId
								ELSE 0
							END,
					AwayId = CASE
								WHEN b.Product IN ('SB', 'CO', 'NG', 'VS', 'VS2', 'LG', 'VS4') THEN m.awayid
								WHEN b.EventType = 5 THEN m3rd.AwayId
								ELSE 0
							END,
					IsNeutral = CASE
									WHEN b.Product IN ('SB', 'CO', 'NG', 'VS', 'VS2', 'LG') THEN ISNULL(m.IsNeutral, 0)
									ELSE 0
								END,
					ShowTime = CASE
									WHEN b.Product IN ('VS', 'VS2', 'LG', 'VS4') THEN CONVERT(NVARCHAR(50), m.kickofftime)
									WHEN b.Product IN ('SB', 'CO', 'NG') THEN ISNULL(m.showtime, '')
									WHEN b.EventType = 5 THEN CONVERT(NVARCHAR(50), m3rd.StartTime)
									ELSE ''
								END,
					BetCheck = CASE
									WHEN b.Product IN ('SB', 'CO', 'Parlay', 'ParlayVS2', 'VRG', 'H5LG', 'SLT', 'ParlayVS5') THEN ISNULL(b.betcheck, '')
									WHEN b.Product IN ('Keno') THEN ISNULL(b.comstatus, '')
									ELSE ''
								END,
					ComStatus = CASE WHEN b.comstatus = '1' THEN '1' ELSE '0' END,
					TransDesc = CASE
									WHEN b.Product IN ('SB', 'CO', 'VS2', 'OneRNG', 'CC', 'SG', 'Keno', 'VB', 'NG2', 'Lottery', 
										'PP', 'VRG', 'TG', 'I4D', 'PGS', 'JK', 'VS3', 'H5LG', 'SLT', 'HB', 'CG', 'AP', 'APM', 'SEA', 'LG', 'VS4', 'VS5') THEN ISNULL(b.transdesc, '')
									WHEN b.EventType = 3 THEN ISNULL(b.transdesc, '')
									ELSE ''
								END,
					OddsSpread = CASE
									WHEN b.Product IN ('SB', 'CO', 'OneRNG', 'PP', 'SG',  'SBC', 'VGA', 'Parlay') THEN ISNULL(b.oddsspread, 0)
									WHEN b.SubProduct LIKE 'Jackpot%' THEN  ISNULL(b.oddsspread, 0)
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
					Discount = CASE
									WHEN bt.recommend IN (-3, -4) THEN 0
									ELSE b.discount
								END,
					ADiscount = CASE
									WHEN bt.mrecommend = -4 THEN 0
									ELSE b.adiscount
								END
				FROM @Data AS b
					LEFT JOIN dbo.match14 AS m WITH (NOLOCK) ON b.Product IN ('SB', 'CO', 'NG', 'VS', 'VS2', 'LG', 'VS4') AND b.matchid = m.matchid
					LEFT JOIN dbo.outright14 AS o WITH (NOLOCK) ON b.Product IN ('Outright') AND b.matchid = o.orid
					LEFT JOIN dbo.League AS l WITH (NOLOCK) ON b.Product IN ('Outright') AND o.leagueid = l.leagueid
					LEFT JOIN dbo.VSRaceInfo14 AS vr WITH (NOLOCK) ON b.EventType = 3 AND vr.EventID = b.matchid
					LEFT JOIN dbo.match3rd14 AS m3rd WITH (NOLOCK) ON b.EventType = 5 AND b.matchid = m3rd.match3rdid
					LEFT JOIN dbo.bettrans14 AS bt WITH (NOLOCK) ON bt.TransId = b.TransId
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
					WHERE b.Product = 'TIP'
						AND b.TableID = 2
				END
			END

			-- bettrans_bk range
			IF EXISTS (SELECT TOP(1) 1 FROM @Data WHERE TableID = 3)
			BEGIN
				UPDATE b
				SET
					TransId = CASE
								WHEN b.Product = 'Parlay' AND b.bettype = 29 AND ISNULL(b.betid, 0) > 0 THEN b.betid
								ELSE b.transid
							END,
					SportType = CASE
									WHEN b.Product IN ('OneRNG', 'CC', 'NPHP', 'SG', 'VRG', 'SAG', 'TG', 'SBC', 'I4D', 'SXG', 'IBCLC', 'BBIN', 'ION', 
										'PGS', 'JK', 'RNGW', 'WM', 'VS3', 'BG', 'H5LG', 'MXG', 'SLT', 'PPL', 'HB', 'CG', 'VGA', 'AP', 'APM', 'FGGL', 
										'SEA', 'MGRNG', 'TIP', 'JIG', 'YB', 'WE', 'L22', 'UUSL', 'SNG', 'SAC') THEN b.matchid
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
									WHEN b.EventType = 3 THEN vr.SportType
									WHEN b.EventType = 5 THEN m3rd.sporttype
									WHEN b.RefTable IN (1, 2) THEN b.matchid
									WHEN b.EventType = 5 THEN m3rd.sporttype
									ELSE 0
								END,
					BetTeam = CASE
									WHEN b.Product IN ('SB', 'CO', 'NG', 'VS', 'VS2', 'Parlay', 'ParlayVS2', 'BTC', 'LG', 'VS4', 'ParlayVS4', 'VS5', 'ParlayVS5', 'VS6') THEN b.betteam
									WHEN b.EventType = 3 THEN b.betteam
									ELSE ''
								END,
					Hdp1 = CASE
								WHEN b.Product IN ('SB', 'CO', 'NG', 'VS', 'VS2', 'Parlay', 'ParlayVS2', 'NG2', 'BTC', 'LG', 'VS4', 'ParlayVS4', 'VS5', 'ParlayVS5', 'VS6') THEN b.hdp1
								ELSE 0
							END,
					Hdp2 = CASE
								WHEN b.Product IN ('SB', 'CO', 'VS', 'VS2', 'Parlay', 'ParlayVS2', 'NG2', 'LG', 'VS4', 'ParlayVS4', 'VS5', 'ParlayVS5', 'VS6') THEN b.hdp2
								ELSE 0
							END,
					OddsType = CASE
									WHEN b.Product IN ('SB', 'Outright', 'CO', 'NG', 'VS', 'VS2', 'LG', 'VS4', 'VS5', 'VS6') THEN b.oddstype
									ELSE 0
								END,
					Odds = CASE
								WHEN b.Product IN ('SB', 'CO', 'NG', 'VS', 'VS2', 'Outright', 'Parlay', 'OneRNG', 'Keno', 'NG2', 'ParlayVS2', 
									'Lottery', 'VRG', 'TG', 'I4D', 'PP', 'SG', 'VS3', 'SBC', 'H5LG', 'SLT', 'VGA', 'BTC', 'LG', 'VS4', 'ParlayVS4', 'VS6') THEN b.odds
								WHEN b.SubProduct LIKE 'Jackpot%' THEN b.odds
								WHEN b.EventType IN (3, 5) THEN b.odds
								ELSE 0
							END,
					MOdds = CASE
								WHEN b.Product IN ('SB', 'CO', 'NG', 'VS', 'VS2', 'Outright', 'Parlay', 'ParlayVS2', 'LG', 'VS4', 'ParlayVS4', 'VS5', 'ParlayVS5', 'VS6') THEN b.modds
								ELSE 0
							END,
					Status = CASE
								WHEN @IsCN88 = 1 AND b.Product IN ('SB', 'VS', 'VS2') AND b.status = 'Won' AND b.modds = 0.25 THEN 'Half Won'
								WHEN @IsCN88 = 1 AND b.Product IN ('SB', 'VS', 'VS2') AND b.status = 'Lose' AND b.modds = -0.25 THEN 'Half Lose'
								WHEN b.Product = 'TG' AND b.status = 'Won' AND b.modds = 0.25 THEN 'Half Won'
								WHEN b.Product = 'TG' AND b.status = 'Lose' AND b.modds = -0.25 THEN 'Half Lose'
								ELSE b.status
							END,
					SettlementStatus = 0,
					WinLost = b.winlost - b.actual_stake,
					LiveIndicator = CASE
										WHEN b.Product IN ('SB', 'CO', 'NG', 'VS', 'VS2', 'LG', 'VS5', 'VS6') THEN b.liveindicator
										ELSE 0
									END,
					LiveHomeScore = CASE
										WHEN b.Product IN ('SB', 'CO', 'NG', 'VS', 'VS2', 'Outright', 'NG2', 'LG', 'VS5') THEN b.livehomescore
										ELSE 0
									END,
					LiveAwayScore = CASE
										WHEN b.Product IN ('SB', 'CO', 'NG', 'VS', 'VS2', 'Outright', 'LG', 'VS5') THEN b.liveawayscore
										ELSE 0
									END,
					LeagueId = CASE
									WHEN b.Product IN ('SB', 'CO', 'NG', 'VS', 'VS2', 'LG', 'VS4') THEN m.leagueid
									WHEN b.Product IN ('Outright') THEN o.leagueid
									WHEN b.EventType = 3 THEN vr.LeagueID
									WHEN b.EventType = 5 THEN m3rd.League3rdId
									ELSE 0
								END,
					MatchId = CASE
									WHEN b.Product IN ('NG2') THEN b.betdaqid
									WHEN b.Product IN ('SB', 'CO', 'NG', 'VS', 'VS2', 'LG', 'VS4') THEN m.matchid
									WHEN b.Product IN ('Outright') THEN o.orid
									WHEN b.Product IN ('BTC') THEN b.matchid
									WHEN b.EventType IN (3, 5) THEN b.matchid
									WHEN b.Product = 'TIP' THEN ISNULL(CAST(('<xml>' + b.ExtraInfo + '</xml>') AS XML).value('data(/xml/p74/@m)[1]','INT'), 0)
									ELSE 0
								END,
					MatchCode = CASE
									WHEN b.Product IN ('SB', 'CO', 'NG', 'VS', 'VS2', 'LG', 'VS4') THEN m.matchcode
									WHEN b.Product IN ('Outright') THEN o.matchcode
									WHEN b.Product IN ('VS5') THEN m3rd.MatchCode
									ELSE ''
								END,
					Race = CASE
								WHEN b.Product IN ('Outright') THEN o.groupmatch
								ELSE ''
							END,
					EventDate = CASE
									WHEN b.Product IN ('SB', 'CO') THEN m.GlobalShowTime
									WHEN b.Product IN ('NG', 'VS', 'VS2', 'LG', 'VS4') THEN m.eventdate
									WHEN b.Product IN ('Outright') THEN o.eventdate
									ELSE b.winlostdate
								END,
					HomeId = CASE
								WHEN b.Product IN ('SB', 'CO', 'NG', 'VS', 'VS2', 'LG', 'VS4') THEN m.homeid
								WHEN b.Product IN ('Outright') THEN o.teamid
								WHEN b.EventType = 5 THEN m3rd.HomeId
								ELSE 0
							END,
					AwayId = CASE
								WHEN b.Product IN ('SB', 'CO', 'NG', 'VS', 'VS2', 'LG', 'VS4') THEN m.awayid
								WHEN b.EventType = 5 THEN m3rd.AwayId
								ELSE 0
							END,
					IsNeutral = CASE
									WHEN b.Product IN ('SB', 'CO', 'NG', 'VS', 'VS2', 'LG') THEN ISNULL(m.IsNeutral, 0)
									ELSE 0
								END,
					ShowTime = CASE
									WHEN b.Product IN ('VS', 'VS2', 'LG', 'VS4') THEN CONVERT(NVARCHAR(50), m.kickofftime)
									WHEN b.Product IN ('SB', 'CO', 'NG') THEN ISNULL(m.showtime, '')
									WHEN b.EventType = 5 THEN CONVERT(NVARCHAR(50), m3rd.StartTime)
									ELSE ''
								END,
					BetCheck = CASE
									WHEN b.Product IN ('SB', 'CO', 'Parlay', 'ParlayVS2', 'VRG', 'H5LG', 'SLT', 'ParlayVS4', 'ParlayVS5') THEN ISNULL(b.betcheck, '')
									WHEN b.Product IN ('Keno') THEN ISNULL(b.comstatus, '')
									ELSE ''
								END,
					ComStatus = CASE WHEN b.comstatus = '1' THEN '1' ELSE '0' END,
					TransDesc = CASE
									WHEN b.Product IN ('SB', 'CO', 'VS2', 'OneRNG', 'CC', 'SG', 'Keno', 'VB', 'NG2', 'Lottery', 
										'PP', 'VRG', 'TG', 'I4D', 'PGS', 'JK', 'VS3', 'H5LG', 'SLT', 'HB', 'CG', 'AP', 'APM', 'SEA', 'LG', 'VS4', 'VS5') THEN ISNULL(b.transdesc, '')
									WHEN b.EventType = 3 THEN ISNULL(b.transdesc, '')
									ELSE ''
								END,
					OddsSpread = CASE
									WHEN b.Product IN ('SB', 'CO', 'OneRNG', 'PP', 'SG', 'SBC', 'VGA', 'Parlay') THEN ISNULL(b.oddsspread, 0)
									WHEN b.SubProduct LIKE 'Jackpot%' THEN ISNULL(b.oddsspread, 0)
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
					Discount = CASE
									WHEN bt.recommend IN (-3, -4) THEN 0
									ELSE b.discount
								END,
					ADiscount = CASE
									WHEN bt.mrecommend = -4 THEN 0
									ELSE b.adiscount
								END
				FROM @Data AS b
					CROSS APPLY dbo.f_IP_Decompress(b.Ip) AS dp
					LEFT JOIN bodb_Archive.dbo.match_bk AS m WITH (NOLOCK) ON b.Product IN ('SB', 'CO', 'NG', 'VS', 'VS2', 'LG', 'VS4') AND b.matchid = m.matchid
					LEFT JOIN bodb_Archive.dbo.outright_bk AS o WITH (NOLOCK) ON b.Product IN ('Outright') AND b.matchid = o.orid
					LEFT JOIN dbo.League AS l WITH (NOLOCK) ON b.Product IN ('Outright') AND o.leagueid = l.leagueid
					LEFT JOIN bodb_Archive.dbo.VSRaceInfo_bk AS vr WITH (NOLOCK) ON b.EventType = 3 AND vr.EventID = b.matchid
					LEFT JOIN bodb_Archive.dbo.match3rd_bk AS m3rd WITH (NOLOCK) ON b.EventType = 5 AND b.matchid = m3rd.match3rdid
					LEFT JOIN bodb_Archive.dbo.bettrans_bk AS bt WITH (NOLOCK) ON bt.TransId = b.TransId
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
					WHERE b.Product = 'TIP'
						AND b.TableID = 3
				END
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
	DECLARE @CurrencyName	NVARCHAR(50)

	SELECT @CurrencyName = ex.currency
	FROM dbo.Customer AS c WITH (NOLOCK)
		INNER JOIN dbo.Exchange AS ex WITH (NOLOCK) ON c.currency = ex.exchangeid
	WHERE c.custid = @CustId

	DECLARE @TotalRow	INT	= 0

	SELECT @TotalRow = COUNT(1)
	FROM @Data

	IF @TotalRow > @MaxTotalRow
	BEGIN
		DELETE FROM @Data

		SELECT @ErrCode = 100,
			@ErrMsg = N'Exceed max total row.',
			@MaxTotalRow = @TotalRow
	END

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
		b.AWinLost,
		b.MWinLost,
		b.SWinLost,
		b.Commission,
		b.Comm,
		b.AComm,
		b.SComm,
		b.APositionTaking,
		b.MPositionTaking,
		b.SPositionTaking,
		b.PlayerDiscount,
		b.Discount,
		b.ADiscount,
		b.SDiscount,
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
		c.Username,
		c.UGroup,
		b.CurrencyId,
		b.SiteId,
		b.DeviceType
	FROM @Data AS b
		INNER JOIN dbo.Customer AS c WITH (NOLOCK) ON c.custid = b.custid
	ORDER BY b.TransId ASC	
END
GO
