/*<info serverAlias="DBACC-bodb02" executers="bodbAdminNet" viewers="" isFunction="0" isNested="0"></info>*/

ALTER PROCEDURE [dbo].[Acc_BetList_Mem]
	@CustId			INT,
	@BetType		INT				= 0,
	@StatusIdList	VARCHAR(100)	= '',
	@FromDate		SMALLDATETIME,
	@ToDate			SMALLDATETIME,
	@MoveBetsDay	SMALLDATETIME,
	@BalanceUpDay	SMALLDATETIME,
	@IsCN88			BIT				= 0
AS

/*
	Created: 20190925@Kos
	Task: NAP Left Panel => Member Bet List
	DB: DBACC.bodb02
	Original: Acc_BetsSelBetList
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
*/

BEGIN
	SET NOCOUNT ON

	-- Get Sport Bettype Matrix
	DECLARE @SportBettype TABLE(ProductID TINYINT, Bettype SMALLINT, EventType TINYINT)

	DECLARE @IsTest BIT = 0

	SELECT @IsTest = dbo.f_CheckSPVersion(@@PROCID)

	INSERT INTO @SportBettype
	SELECT ProductID, BetType, EventType
	FROM dbo.f_SportBettypeMatrix_Sel (0, 0, 0, 2, '', '', @IsTest)
	WHERE ProductID NOT IN (2, 4, 7, 9, 13, 17, 19, 26, 30, 31, 33)
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
			s.EventType
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
		Ip					NVARCHAR(15),
		BetFrom				NVARCHAR(1),
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
		Tranid3rd			NVARCHAR(64),
		TableID				TINYINT,
		Product				VARCHAR(30)
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

	DECLARE @TempToDate	SMALLDATETIME,
		@TempFromDate	SMALLDATETIME

	DECLARE @Yesterday SMALLDATETIME = DATEADD(DAY, DATEDIFF(DAY, 1, CURRENT_TIMESTAMP), 0)

	-- bettrans range
	IF @ToDate > @MoveBetsDay
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
			BetFrom,
			MatchId,
			BetCheck,
			ComStatus,
			TransDesc,
			BetdaqId,
			ExtraInfo,
			WalletType,
			RefCode,
			TableID)
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
			b.betfrom,
			b.matchid,
			b.betcheck,
			b.comstatus,
			b.transdesc,
			b.betdaqid,
			b.ExtraInfo,
			b.WalletType,
			ISNULL(b.RefCode, 0),
			1 AS TableID
		FROM dbo.bettrans AS b WITH (NOLOCK, INDEX = IX_custid)
			INNER JOIN @SportBettype AS s ON s.Bettype = b.bettype
		WHERE b.custid = @CustId
			AND b.winlostdate BETWEEN @TempFromDate AND @ToDate
			AND (',' + @StatusIdList + ',' LIKE '%,' + CONVERT(VARCHAR(3), b.statusID) + ',%'
				OR (s.ProductID IN (6, 21, 22, 24, 32, 34, 36, 39, 42, 45, 46, 50, 51, 52, 55, 56, 57, 59, 60, 61, 62, 65)
					AND b.winlostdate >= @Yesterday))		-- Don't care status of yesterday and today summary casino rows

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
			BetFrom,
			TransDesc,
			ProductId,
			EventId,
			Custom1,
			Custom2,
			Custom3,
			Gameid3rd,
			Tranid3rd,
			TableID
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
			b.betfrom,
			b.transdesc,
			b.productID,
			b.eventID,
			b.custom1,
			b.custom2,
			b.custom3,
			b.GameId3rd,
			b.TranId3rd,
			4 AS TableID
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
			BetFrom,
			MatchId,
			BetCheck,
			ComStatus,
			TransDesc,
			BetdaqId,
			ExtraInfo,
			WalletType,
			RefCode,
			TableID)
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
			b.betfrom,
			b.matchid,
			b.betcheck,
			b.comstatus,
			b.transdesc,
			b.betdaqid,
			b.ExtraInfo,
			b.WalletType,
			ISNULL(b.RefCode, 0),
			2 AS TableID
		FROM dbo.bettrans14 AS b WITH (NOLOCK, INDEX = IX_memberStatement14)
		WHERE b.custid = @CustId
			AND b.winlostdate BETWEEN @TempFromDate AND @TempToDate
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
			BetFrom,
			MatchId,
			BetCheck,
			ComStatus,
			TransDesc,
			BetdaqId,
			ExtraInfo,
			WalletType,
			RefCode,
			TableID)
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
			b.betfrom,
			b.matchid,
			b.betcheck,
			b.comstatus,
			b.transdesc,
			b.betdaqid,
			b.ExtraInfo,
			b.WalletType,
			ISNULL(b.RefCode, 0),
			3 AS TableID
		FROM bodb_Archive.dbo.bettrans_bk AS b WITH (NOLOCK, INDEX = IX_custid)
		WHERE b.custid = @CustId
			AND b.winlostdate BETWEEN @FromDate AND @TempToDate
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
						WHEN s.ProductID = 12 THEN 'GD'								-- Gold Deluxe
						WHEN s.ProductID = 15 THEN 'CB'								-- Colossus Bet
						WHEN s.EventType = 0 AND s.ProductID = 21 THEN 'AllBet'
						WHEN s.EventType = 0 AND s.ProductID = 22 THEN 'VB'			-- Macau Games
						WHEN s.EventType = 0 AND s.ProductID = 23 THEN 'NG2'
						WHEN s.EventType = 0 AND s.ProductID = 24 THEN 'FW'			-- Fishing World
						WHEN s.EventType = 0 AND s.ProductID = 27 THEN 'ParlayVS2'	-- Betradar Virtual Sports Parlay
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
						WHEN s.ProductID = 49 THEN 'VS3'							-- Leap Gaming Virtual Sports 3
						WHEN s.ProductID = 50 THEN 'RNGW'							-- RNG War
						WHEN s.ProductID = 51 THEN 'WM'								-- WM
						WHEN s.ProductID = 52 THEN 'ION'							-- ION
						WHEN s.ProductID = 55 THEN 'PGS'							-- PG Soft
						WHEN s.ProductID = 56 THEN 'JK'								-- Joker
						WHEN s.ProductID = 57 THEN 'BG'								-- Big Gaming
						WHEN s.ProductID = 59 THEN 'GDG'							-- GDG
						WHEN s.ProductID = 60 THEN 'MXG'							-- MaxGame
						WHEN s.ProductID = 61 THEN 'HB'								-- Habanero
						WHEN s.ProductID = 62 THEN 'CG'								-- CG
						WHEN s.ProductID = 63 THEN 'SLT'							-- Sports Lottery
						WHEN s.ProductID = 65 THEN 'PPL'							-- PP Live Casino
						WHEN s.EventType = 1 AND s.ProductID = 1 THEN 'SB'			-- Sportsbook
						WHEN s.EventType = 1 AND s.ProductID = 3 THEN 'NG'			-- Number Game
						WHEN s.EventType = 1 AND s.ProductID = 5 THEN 'VS'			-- Virtual Sports Sportsbook
						WHEN s.EventType = 1 AND s.ProductID = 27 THEN 'VS2'		-- Betradar Virtual Sports
						WHEN s.EventType = 2 AND s.ProductID = 1 THEN 'Outright'
						WHEN s.EventType = 3 AND s.ProductID = 5 THEN 'VR'			-- Virtual Sports Racing
						WHEN s.EventType = 0 AND s.ProductID = 3 THEN 'H5LG'		-- Happy 5 Linked Games
						ELSE 'Unknown'
					END
		FROM @Data AS b
			INNER JOIN @SportBettype AS s ON b.BetType = s.BetType

		DELETE @Data
		WHERE Product = 'Unknown'
			OR Product IS NULL
			OR BetType IN (903, 904, 913, 914)
			OR (Product <> 'SB'
				AND (Product NOT IN ('OneRNG', 'AllBet', 'VB', 'FW', 'PP', 'CC', 'SG', 'SAG', 'SBC', 'RNGW', 'SXG', 'IBCLC', 'ION', 'PGS', 'JK', 'WM', 'GDG', 'BG', 'MXG', 'PPL', 'HB', 'CG')
					OR WinLostDate < @Yesterday)
				AND ',' + @OriginalStatusIdList + ',' NOT LIKE '%,' + CONVERT(VARCHAR(3), StatusId) + ',%')
			OR (',' + @OriginalStatusIdList + ',' NOT LIKE '%,99,%'		-- Abnormal Bets
				AND Status = 'Void'
				AND ISNULL(CAST(('<xml>' + ExtraInfo + '</xml>') AS XML).value('data(/xml/p1/@ab)[1]','TINYINT'), 0) = 1)
			OR (',' + @OriginalStatusIdList + ',' NOT LIKE '%,102,%'	-- Void
				AND Status = 'Void'
				AND ISNULL(CAST(('<xml>' + ExtraInfo + '</xml>') AS XML).value('data(/xml/p1/@ab)[1]','TINYINT'), 0) = 0)

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
							AND ExtraInfo LIKE '%p25%'))
					AND ((Status = 'Draw' AND ',' + @OriginalStatusIdList + ',' NOT LIKE '%,111,%')
						OR (Status = 'Won' AND ',' + @OriginalStatusIdList + ',' NOT LIKE '%,112,%')
						OR (Status = 'Lose' AND ',' + @OriginalStatusIdList + ',' NOT LIKE '%,113,%'))
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
			END

			IF ',' + @OriginalStatusIdList + ',' NOT LIKE '%,3,%'	-- Not include Under Settlement
			BEGIN
				DELETE @Data
				WHERE Product = 'SB'
					AND Status = 'Running'
					AND (ISNULL(SecAcceptFlag, 0) = 0 OR ISNULL(CheckTime, CURRENT_TIMESTAMP) <= CURRENT_TIMESTAMP)			-- not Waiting (Second Accept)
					AND ISNULL(SettlementStatus, 0) & 12 <> 0	-- isUnderSettlement flag (bit 3) = 1 OR isSystemSettlement flag (bit 4) = 1
					AND ISNULL(SettlementStatus, 0) & 1 = 0		-- isPending flag (bit 1) = 0
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

			-- Get yesterday and today running and settled bettransRnG/bettransLC tickets
			IF EXISTS ( SELECT 1 FROM @Data
						WHERE Product IN ('VB', 'FW', 'PP', 'OneRNG', 'CC', 'SG', 'SBC', 'RNGW', 'PGS', 'JK', 'MXG', 'HB', 'CG') AND WinLostDate >= @Yesterday)	-- bettransRnG
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
						AVG(brng.discount) AS discount,
						AVG(brng.adiscount) AS adiscount,
						AVG(brng.sdiscount) AS sdiscount,
						0 AS OddsSpread
					FROM @Data AS c
						INNER JOIN dbo.bettransRnG AS brng WITH (NOLOCK) ON brng.RefNo = c.TransId
					WHERE c.Product IN ('VB', 'FW', 'PP', 'OneRNG', 'CC', 'SG', 'SBC', 'RNGW', 'PGS', 'JK', 'MXG', 'HB', 'CG')
						AND c.WinLostDate >= @Yesterday
						AND brng.statusID IN (0, 1)
					GROUP BY
						c.TransId,
						c.Product
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
							WHEN Product IN ('OneRNG', 'PP', 'SBC') THEN ISNULL(AVG(CASE WHEN brng.statusID IN (111, 112, 113) THEN brng.ContributionRate END), 0)
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
						AVG(brng.discount) AS discount,
						AVG(brng.adiscount) AS adiscount,
						AVG(brng.sdiscount) AS sdiscount,
						CASE
							WHEN c.Product IN ('OneRNG', 'PP', 'SBC') THEN ISNULL(SUM(brng.BetStake), 0)
							ELSE 0
						END AS OddsSpread
					FROM @Data AS c
						INNER JOIN dbo.bettransRnG AS brng WITH (NOLOCK) ON brng.RefNo = c.TransId
					WHERE c.Product IN ('VB', 'FW', 'PP', 'OneRNG', 'CC', 'SG', 'SBC', 'RNGW', 'PGS', 'JK', 'MXG', 'HB', 'CG')
						AND c.WinLostDate >= @Yesterday
						AND brng.statusID NOT IN (0, 1)
					GROUP BY
						c.TransId,
						c.Product
				END
			END

			IF EXISTS (SELECT 1 FROM @Data WHERE Product IN ('Allbet', 'SAG', 'SXG', 'IBCLC', 'ION', 'WM', 'GDG', 'BG', 'PPL') AND WinLostDate >= @Yesterday)		-- bettransLC
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
						AVG(blc.discount) AS discount,
						AVG(blc.adiscount) AS adiscount,
						AVG(blc.sdiscount) AS sdiscount,
						0 AS OddsSpread
					FROM @Data AS c
						INNER JOIN dbo.bettransLC AS blc WITH (NOLOCK) ON blc.RefNo = c.TransId
					WHERE c.Product IN ('Allbet', 'SAG', 'SXG', 'IBCLC', 'ION', 'WM', 'GDG', 'BG', 'PPL')
						AND c.WinLostDate >= @Yesterday
						AND blc.statusID IN (0, 1)
					GROUP BY
						c.TransId,
						c.Product
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
						AVG(blc.discount) AS discount,
						AVG(blc.adiscount) AS adiscount,
						AVG(blc.sdiscount) AS sdiscount,
						0 AS OddsSpread
					FROM @Data AS c
						INNER JOIN dbo.bettransLC AS blc WITH (NOLOCK) ON blc.RefNo = c.TransId
					WHERE c.Product IN ('Allbet', 'SAG', 'SXG', 'IBCLC', 'ION', 'WM', 'GDG', 'BG', 'PPL')
						AND c.WinLostDate >= @Yesterday
						AND blc.statusID NOT IN (0, 1)
					GROUP BY
						c.TransId,
						c.Product
				END
			END

			DELETE FROM @TmpData
			WHERE (Status = 'Draw' AND ',' + @OriginalStatusIdList + ',' NOT LIKE '%,111,%')
				OR (Status = 'Won' AND ',' + @OriginalStatusIdList + ',' NOT LIKE '%,112,%')
				OR (Status = 'Lose' AND ',' + @OriginalStatusIdList + ',' NOT LIKE '%,113,%')

			DELETE b
			FROM @Data AS b
			WHERE b.Product IN ('VB', 'FW', 'PP', 'OneRNG', 'CC', 'SG', 'SBC', 'RNGW', 'PGS', 'JK', 'MXG', 'HB', 'CG', 'Allbet', 'SAG', 'SXG', 
					'IBCLC', 'ION', 'WM', 'GDG', 'BG', 'PPL')
				AND b.Winlostdate >= @Yesterday
				AND NOT EXISTS (SELECT 1 FROM @TmpData WHERE RefNo = b.TransId)

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
										'JK', 'WM', 'GDG', 'VS3', 'BG', 'H5LG', 'MXG', 'SLT', 'PPL', 'HB', 'CG') THEN b.matchid
									WHEN b.Product = 'Keno' THEN 202	-- Keno
									WHEN b.Product = 'Lottery' THEN 220	-- Lottery
									WHEN b.Product = 'GD' THEN 255		-- Gold Deluxe
									WHEN b.Product = 'AllBet' THEN 211	-- AllBet
									WHEN b.Product = 'VB' THEN 212		-- Macau Games
									WHEN b.Product = 'NG2' AND b.bettype BETWEEN 2501 AND 2539 THEN 213 -- NG2
									WHEN b.Product = 'NG2' AND b.bettype BETWEEN 2541 AND 2579 THEN 214 -- NG2
									WHEN b.Product = 'NG2' AND b.bettype BETWEEN 2581 AND 2619 THEN 215 -- NG2
									WHEN b.Product = 'NG2' AND b.bettype BETWEEN 2621 AND 2659 THEN 216 -- NG2
									WHEN b.Product = 'NG2' AND b.bettype BETWEEN 2681 AND 2699 THEN 218 -- NG2
									WHEN b.Product = 'FW' THEN 219		-- Fishing World
									WHEN b.Product = 'PP' THEN 248		-- Pragmatic Casino
									WHEN b.Product = 'CB' THEN 204		-- Colossus Bet
									WHEN b.Product IN ('SB', 'CO', 'NG', 'VS', 'VS2') THEN m.sporttype
									WHEN b.Product IN ('Outright') THEN l.sporttype
									WHEN b.Product IN ('VR') THEN vr.SportType
									ELSE 0
								END,
					BetTeam = CASE
									WHEN b.Product IN ('SB', 'CO', 'NG', 'VS', 'VS2', 'Parlay', 'ParlayVS2') THEN b.betteam
									ELSE ''
								END,
					Hdp1 = CASE
								WHEN b.Product IN ('SB', 'CO', 'NG', 'VS', 'VS2', 'VR', 'Parlay', 'ParlayVS2', 'NG2') THEN b.hdp1
								ELSE 0
							END,
					Hdp2 = CASE
								WHEN b.Product IN ('SB', 'CO', 'VS', 'VS2', 'VR', 'Parlay', 'ParlayVS2', 'NG2') THEN b.hdp2
								ELSE 0
							END,
					OddsType = CASE
									WHEN b.Product IN ('SB', 'CO', 'NG', 'VS', 'VS2') THEN b.oddstype
									ELSE 0
								END,
					Odds = CASE
								WHEN b.Product IN ('SB', 'CO', 'NG', 'VS', 'VS2', 'Outright', 'VR', 'Parlay', 'OneRNG', 'Keno', 'GD', 'NG2', 'ParlayVS2', 
									'Lottery', 'VRG', 'TG', 'I4D', 'PP', 'VS3', 'SBC', 'SLT') THEN b.odds
								ELSE 0
							END,
					MOdds = CASE
								WHEN b.Product IN ('SB', 'CO', 'NG', 'VS', 'VS2', 'Outright', 'VR', 'Parlay', 'ParlayVS2') THEN b.modds
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
										WHEN b.Product IN ('SB', 'CO', 'NG', 'VS', 'VS2') THEN b.liveindicator
										ELSE 0
									END,
					LiveHomeScore = CASE
										WHEN b.Product IN ('SB', 'CO', 'NG', 'VS', 'VS2', 'Outright', 'VR', 'NG2') THEN b.livehomescore
										ELSE 0
									END,
					LiveAwayScore = CASE
										WHEN b.Product IN ('SB', 'CO', 'NG', 'VS', 'VS2', 'Outright', 'VR') THEN b.liveawayscore
										ELSE 0
									END,
					LeagueId = CASE
									WHEN b.Product IN ('SB', 'CO', 'NG', 'VS', 'VS2') THEN m.leagueid
									WHEN b.Product IN ('Outright') THEN o.leagueid
									WHEN b.Product IN ('VR') THEN vr.LeagueID
									ELSE 0
								END,
					MatchId = CASE
									WHEN b.Product IN ('GD') THEN 255
									WHEN b.Product IN ('NG2') THEN b.betdaqid
									WHEN b.Product IN ('SB', 'CO', 'NG', 'VS', 'VS2') THEN m.matchid
									WHEN b.Product IN ('Outright') THEN o.orid
									WHEN b.Product IN ('VR') THEN b.matchid
									ELSE 0
								END,
					MatchCode = CASE
									WHEN b.Product IN ('SB', 'CO', 'NG', 'VS', 'VS2') THEN m.matchcode
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
									WHEN b.Product IN ('NG', 'VS', 'VS2') THEN m.eventdate
									WHEN b.Product IN ('Outright') THEN o.eventdate
									WHEN b.Product IN ('VR') THEN vo.EventDate
									ELSE b.winlostdate
								END,
					HomeId = CASE
								WHEN b.Product IN ('SB', 'CO', 'NG', 'VS', 'VS2') THEN m.homeid
								WHEN b.Product IN ('Outright') THEN o.teamid
								WHEN b.Product IN ('VR') THEN vo.RacerID
								ELSE 0
							END,
					AwayId = CASE
								WHEN b.Product IN ('SB', 'CO', 'NG', 'VS', 'VS2') THEN m.awayid
								ELSE 0
							END,
					IsNeutral = CASE
									WHEN b.Product IN ('SB', 'CO', 'NG', 'VS', 'VS2') THEN ISNULL(m.IsNeutral, 0)
									ELSE 0
								END,
					ShowTime = CASE
									WHEN b.Product IN ('VS', 'VS2') THEN CONVERT(NVARCHAR(50), m.kickofftime)
									WHEN b.Product IN ('SB', 'NG') THEN ISNULL(m.showtime, '')
									WHEN b.Product IN ('VR') THEN CONVERT(NVARCHAR(50), vr.EventTime)
									ELSE ''
								END,
					BetCheck = CASE
									WHEN b.Product IN ('SB', 'CO', 'Parlay', 'ParlayVS2', 'GD', 'VRG', 'H5LG', 'SLT') THEN ISNULL(b.betcheck, '')
									WHEN b.Product IN ('Keno') THEN ISNULL(b.comstatus, '')
									WHEN b.Product IN ('CB') THEN ISNULL(bm.betcheck, '')
									ELSE ''
								END,
					ComStatus = CASE WHEN b.comstatus = '1' THEN '1' ELSE '0' END,
					TransDesc = CASE
									WHEN b.Product IN ('SB', 'CO', 'VS2', 'OneRNG', 'CC', 'SG', 'Keno', 'VB', 'NG2', 'FW', 'Lottery', 
										'PP', 'TG', 'VRG', 'I4D', 'PGS', 'JK', 'VS3', 'H5LG', 'SLT', 'HB', 'CG') THEN ISNULL(b.transdesc, '')
									ELSE ''
								END,
					OddsSpread = CASE
									WHEN b.Product IN ('SB', 'CO', 'OneRNG', 'PP', 'SBC') THEN ISNULL(b.oddsspread, 0)
									ELSE 0
								END,
					BetdaqId = CASE
									WHEN b.Product IN ('SB', 'CO') THEN ISNULL(b.betdaqid, -1)
									ELSE -1
								END,
					ExtraInfo = CASE
									WHEN b.Product IN ('SB', 'Parlay', 'NPHP', 'VS3') THEN ISNULL(b.ExtraInfo, '')
									ELSE ''
								END,
					WalletType = CASE
									WHEN b.Product IN ('SB') THEN ISNULL(b.WalletType, 0)
									ELSE 0
								END,
					RefCode = CASE
									WHEN b.Product IN ('SB') THEN ISNULL(b.RefCode, 0)
									ELSE 0
								END
				FROM @Data AS b
					LEFT JOIN dbo.match AS m WITH (NOLOCK) ON b.Product IN ('SB', 'CO', 'NG', 'VS', 'VS2') AND b.matchid = m.matchid
					LEFT JOIN dbo.bettransm AS bm WITH (NOLOCK) ON b.Product = 'CB' AND bm.refno = b.refno AND bm.bettype = 18001
					LEFT JOIN dbo.outright AS o WITH (NOLOCK) ON b.Product IN ('Outright') AND b.matchid = o.orid
					LEFT JOIN dbo.League AS l WITH (NOLOCK) ON b.Product IN ('Outright') AND o.leagueid = l.leagueid
					LEFT JOIN dbo.VSOutright AS vo WITH (NOLOCK) ON b.Product IN ('VR') AND b.oddsid = vo.Orid
					LEFT JOIN dbo.VSRaceInfo AS vr WITH (NOLOCK) ON b.Product IN ('VR') AND vr.EventID = vo.EventID
				WHERE b.TableID = 1
					AND (b.Product NOT IN ('VB', 'FW', 'PP', 'OneRNG', 'CC', 'SG', 'SBC', 'RNGW', 'PGS', 'JK', 'MXG', 'HB', 'CG', 'Allbet', 'SAG', 'SXG', 
							'IBCLC', 'ION', 'WM', 'GDG', 'BG', 'PPL')
						OR b.WinLostDate < @Yesterday)

				-- translog
				UPDATE b
				SET SportType = CASE
									WHEN b.BetType BETWEEN 801 AND 806 THEN m.sporttype
									WHEN b.Product = 'Keno' THEN 202
									WHEN b.Product = 'GD' THEN 255			-- Gold Deluxe
									WHEN b.Product = 'CB' THEN 204			-- Colossus Bet
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
								WHEN b.Product IN ('Keno', 'Lottery', 'GD', 'VRG', 'TG', 'I4D', 'VS3', 'SLT') THEN b.Odds
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
									WHEN b.Product IN ('GD') THEN 255
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
									WHEN b.Product IN ('GD', 'VRG', 'H5LG', 'SLT') THEN b.Gameid3rd
									WHEN b.Product IN ('Keno') THEN ISNULL(b.custom2, '')
									WHEN b.Product IN ('CB') THEN b.Tranid3rd
									WHEN b.Product IN ('VS3') THEN ISNULL(b.custom1, '')
									ELSE ''
								END,
					ComStatus = 0,
					TransDesc = CASE
									WHEN b.BetType BETWEEN 801 AND 806 THEN b.transdesc
									WHEN b.Product IN ('Keno', 'Lottery', 'CB', 'VRG', 'TG', 'I4D', 'VS3', 'H5LG', 'SLT') THEN b.transdesc
									ELSE ''
								END,
					OddsSpread = 0,
					BetdaqId = -1,
					ExtraInfo = ''
				FROM @Data AS b
					LEFT JOIN dbo.match AS m WITH (NOLOCK) ON b.BetType BETWEEN 801 AND 806 AND b.eventid = m.matchid
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
					Ip					NVARCHAR(15),
					BetFrom				NVARCHAR(1),
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
					Tranid3rd			NVARCHAR(64),
					TableID				TINYINT,
					Product				VARCHAR(30)
				)

				INSERT INTO @TmpCasinoData
				SELECT
					b.TransId,
					b.RefNo,
					b.CustId,
					b.Creator,
					b.Currency,
					CASE
						WHEN b.Product IN ('OneRNG', 'CC', 'SG', 'SAG', 'SBC', 'SXG', 'IBCLC', 'ION', 'PGS', 'JK', 'WM', 'GDG', 'BG', 'MXG', 'PPL', 'HB', 'CG') THEN b.matchid
						WHEN b.Product = 'AllBet' THEN 211 -- AllBet
						WHEN b.Product = 'VB' THEN 212 -- Macau Games
						WHEN b.Product = 'FW' THEN 219 -- Fishing World
						WHEN b.Product = 'PP' THEN 248 -- Pragmatic Casino
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
						WHEN b.Product IN ('OneRNG', 'PP', 'SBC') THEN x.OddsSpread
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
					b.BetFrom,
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
						WHEN b.Product IN ('OneRNG', 'VB', 'FW', 'PP', 'CC', 'SG', 'PGS', 'JK', 'HB', 'CG') THEN b.transdesc
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
					b.Product
				FROM @Data AS b
					INNER JOIN @TmpData AS x ON x.RefNo = b.TransId
				WHERE b.Product IN ('VB', 'FW', 'PP', 'OneRNG', 'CC', 'SG', 'SBC', 'RNGW', 'MXG', 'HB', 'CG', 'Allbet', 'SAG', 'SXG', 'IBCLC', 'ION', 
						'PGS', 'JK', 'WM', 'GDG', 'BG', 'PPL')
					AND b.WinLostDate >= @Yesterday

				DELETE FROM @Data
				WHERE Product IN ('VB', 'FW', 'PP', 'OneRNG', 'CC', 'SG', 'SBC', 'RNGW', 'MXG', 'HB', 'CG', 'Allbet', 'SAG', 'SXG', 'IBCLC', 'ION', 
						'PGS', 'JK', 'WM', 'GDG', 'BG', 'PPL')
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
	
				UNION ALL -- Gold Deluxe
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
					bg.transdesc
				FROM @Data AS c
					INNER JOIN dbo.bettransg AS bg WITH (NOLOCK) ON c.TransId = bg.refno
				WHERE c.Product = 'GD' AND bg.custid = @CustId
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
										'JK', 'WM', 'GDG', 'VS3', 'BG', 'H5LG', 'MXG', 'SLT', 'PPL', 'HB', 'CG') THEN b.matchid
									WHEN b.Product = 'Keno' THEN 202	-- Keno
									WHEN b.Product = 'Lottery' THEN 220	-- Lottery
									WHEN b.Product = 'GD' THEN 255		-- Gold Deluxe
									WHEN b.Product = 'AllBet' THEN 211	-- AllBet
									WHEN b.Product = 'VB' THEN 212		-- Macau Games
									WHEN b.Product = 'NG2' AND b.bettype BETWEEN 2501 AND 2539 THEN 213 -- NG2
									WHEN b.Product = 'NG2' AND b.bettype BETWEEN 2541 AND 2579 THEN 214 -- NG2
									WHEN b.Product = 'NG2' AND b.bettype BETWEEN 2581 AND 2619 THEN 215 -- NG2
									WHEN b.Product = 'NG2' AND b.bettype BETWEEN 2621 AND 2659 THEN 216 -- NG2
									WHEN b.Product = 'NG2' AND b.bettype BETWEEN 2681 AND 2699 THEN 218 -- NG2
									WHEN b.Product = 'FW' THEN 219		-- Fishing World
									WHEN b.Product = 'PP' THEN 248		-- Pragmatic Casino
									WHEN b.Product = 'CB' THEN 204		-- Colossus Bet
									WHEN b.Product IN ('SB', 'CO', 'NG', 'VS', 'VS2') THEN m.sporttype
									WHEN b.Product IN ('Outright') THEN l.sporttype
									WHEN b.Product IN ('VR') THEN vr.SportType
									ELSE 0
								END,
					BetTeam = CASE
									WHEN b.Product IN ('SB', 'CO', 'NG', 'VS', 'VS2', 'Parlay', 'ParlayVS2') THEN b.betteam
									ELSE ''
								END,
					Hdp1 = CASE
								WHEN b.Product IN ('SB', 'CO', 'NG', 'VS', 'VS2', 'VR', 'Parlay', 'ParlayVS2', 'NG2') THEN b.hdp1
								ELSE 0
							END,
					Hdp2 = CASE
								WHEN b.Product IN ('SB', 'CO', 'VS', 'VS2', 'VR', 'Parlay', 'ParlayVS2', 'NG2') THEN b.hdp2
								ELSE 0
							END,
					OddsType = CASE
									WHEN b.Product IN ('SB', 'CO', 'NG', 'VS', 'VS2') THEN b.oddstype
									ELSE 0
								END,
					Odds = CASE
								WHEN b.Product IN ('SB', 'CO', 'NG', 'VS', 'VS2', 'Outright', 'VR', 'Parlay', 'OneRNG', 'Keno', 'GD', 'NG2', 'ParlayVS2', 
									'Lottery', 'VRG', 'TG', 'I4D', 'PP', 'VS3', 'SBC', 'SLT') THEN b.odds
								ELSE 0
							END,
					MOdds = CASE
								WHEN b.Product IN ('SB', 'CO', 'NG', 'VS', 'VS2', 'Outright', 'VR', 'Parlay', 'ParlayVS2') THEN b.modds
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
										WHEN b.Product IN ('SB', 'CO', 'NG', 'VS', 'VS2') THEN b.liveindicator
										ELSE 0
									END,
					LiveHomeScore = CASE
										WHEN b.Product IN ('SB', 'CO', 'NG', 'VS', 'VS2', 'Outright', 'VR', 'NG2') THEN b.livehomescore
										ELSE 0
									END,
					LiveAwayScore = CASE
										WHEN b.Product IN ('SB', 'CO', 'NG', 'VS', 'VS2', 'Outright', 'VR') THEN b.liveawayscore
										ELSE 0
									END,
					LeagueId = CASE
									WHEN b.Product IN ('SB', 'CO', 'NG', 'VS', 'VS2') THEN m.leagueid
									WHEN b.Product IN ('Outright') THEN o.leagueid
									WHEN b.Product IN ('VR') THEN vr.LeagueID
									ELSE 0
								END,
					MatchId = CASE
									WHEN b.Product IN ('GD') THEN 255
									WHEN b.Product IN ('NG2') THEN b.betdaqid
									WHEN b.Product IN ('SB', 'CO', 'NG', 'VS', 'VS2') THEN m.matchid
									WHEN b.Product IN ('Outright') THEN o.orid
									WHEN b.Product IN ('VR') THEN b.matchid
									ELSE 0
								END,
					MatchCode = CASE
									WHEN b.Product IN ('SB', 'CO', 'NG', 'VS', 'VS2') THEN m.matchcode
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
									WHEN b.Product IN ('NG', 'VS', 'VS2') THEN m.eventdate
									WHEN b.Product IN ('Outright') THEN o.eventdate
									WHEN b.Product IN ('VR') THEN vo.EventDate
									ELSE b.winlostdate
								END,
					HomeId = CASE
								WHEN b.Product IN ('SB', 'CO', 'NG', 'VS', 'VS2') THEN m.homeid
								WHEN b.Product IN ('Outright') THEN o.teamid
								WHEN b.Product IN ('VR') THEN vo.RacerID
								ELSE 0
							END,
					AwayId = CASE
								WHEN b.Product IN ('SB', 'CO', 'NG', 'VS', 'VS2') THEN m.awayid
								ELSE 0
							END,
					IsNeutral = CASE
									WHEN b.Product IN ('SB', 'CO', 'NG', 'VS', 'VS2') THEN ISNULL(m.IsNeutral, 0)
									ELSE 0
								END,
					ShowTime = CASE
									WHEN b.Product IN ('VS', 'VS2') THEN CONVERT(NVARCHAR(50), m.kickofftime)
									WHEN b.Product IN ('SB', 'CO', 'NG') THEN ISNULL(m.showtime, '')
									WHEN b.Product IN ('VR') THEN CONVERT(NVARCHAR(50), vr.EventTime)
									ELSE ''
								END,
					BetCheck = CASE
									WHEN b.Product IN ('SB', 'CO', 'Parlay', 'ParlayVS2', 'GD', 'VRG', 'H5LG', 'SLT') THEN ISNULL(b.betcheck, '')
									WHEN b.Product IN ('Keno') THEN ISNULL(b.comstatus, '')
									WHEN b.Product IN ('CB') THEN ISNULL(bm.betcheck, '')
									ELSE ''
								END,
					ComStatus = CASE WHEN b.comstatus = '1' THEN '1' ELSE '0' END,
					TransDesc = CASE
									WHEN b.Product IN ('SB', 'CO', 'VS2', 'OneRNG', 'CC', 'SG', 'Keno', 'VB', 'NG2', 'FW', 'Lottery', 
										'PP', 'VRG', 'TG', 'I4D', 'PGS', 'JK', 'VS3', 'H5LG', 'SLT', 'HB', 'CG') THEN ISNULL(b.transdesc, '')
									ELSE ''
								END,
					OddsSpread = CASE
									WHEN b.Product IN ('SB', 'CO', 'OneRNG', 'PP', 'SBC') THEN ISNULL(b.oddsspread, 0)
									ELSE 0
								END,
					BetdaqId = CASE
									WHEN b.Product IN ('SB', 'CO') THEN ISNULL(b.betdaqid, -1)
									ELSE -1
								END,
					ExtraInfo = CASE
									WHEN b.Product IN ('SB', 'Parlay', 'NPHP', 'VS3') THEN ISNULL(b.ExtraInfo, '')
									ELSE ''
								END,
					WalletType = CASE
									WHEN b.Product IN ('SB') THEN ISNULL(b.WalletType, 0)
									ELSE 0
								END,
					RefCode = CASE
									WHEN b.Product IN ('SB') THEN ISNULL(b.RefCode, 0)
									ELSE 0
								END
				FROM @Data AS b
					LEFT JOIN dbo.match14 AS m WITH (NOLOCK) ON b.Product IN ('SB', 'CO', 'NG', 'VS', 'VS2') AND b.matchid = m.matchid
					LEFT JOIN dbo.bettransm14 AS bm WITH (NOLOCK) ON b.Product = 'CB' AND bm.refno = b.refno AND bm.bettype = 18001
					LEFT JOIN dbo.outright14 AS o WITH (NOLOCK) ON b.Product IN ('Outright') AND b.matchid = o.orid
					LEFT JOIN dbo.League AS l WITH (NOLOCK) ON b.Product IN ('Outright') AND o.leagueid = l.leagueid
					LEFT JOIN dbo.VSOutright14 AS vo WITH (NOLOCK) ON b.Product IN ('VR') AND b.oddsid = vo.Orid
					LEFT JOIN dbo.VSRaceInfo14 AS vr WITH (NOLOCK) ON b.Product IN ('VR') AND vr.EventID = vo.EventID
				WHERE b.TableID = 2

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
	
				UNION ALL -- Gold Deluxe
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
					bg.transdesc
				FROM @Data AS c
					INNER JOIN dbo.bettransg14 AS bg WITH (NOLOCK) ON c.TransId = bg.refno
				WHERE c.Product = 'GD' AND bg.custid = @CustId
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
										'PGS', 'JK', 'WM', 'GDG', 'VS3', 'BG', 'H5LG', 'MXG', 'SLT', 'PPL', 'HB', 'CG') THEN b.matchid
									WHEN b.Product = 'Keno' THEN 202	-- Keno
									WHEN b.Product = 'Lottery' THEN 220	-- Lottery
									WHEN b.Product = 'GD' THEN 255		-- Gold Deluxe
									WHEN b.Product = 'AllBet' THEN 211	-- AllBet
									WHEN b.Product = 'VB' THEN 212		-- Macau Games
									WHEN b.Product = 'NG2' AND b.bettype BETWEEN 2501 AND 2539 THEN 213 -- NG2
									WHEN b.Product = 'NG2' AND b.bettype BETWEEN 2541 AND 2579 THEN 214 -- NG2
									WHEN b.Product = 'NG2' AND b.bettype BETWEEN 2581 AND 2619 THEN 215 -- NG2
									WHEN b.Product = 'NG2' AND b.bettype BETWEEN 2621 AND 2659 THEN 216 -- NG2
									WHEN b.Product = 'NG2' AND b.bettype BETWEEN 2681 AND 2699 THEN 218 -- NG2
									WHEN b.Product = 'FW' THEN 219		-- Fishing World
									WHEN b.Product = 'PP' THEN 248		-- Pragmatic Casino
									WHEN b.Product = 'CB' THEN 204		-- Colossus Bet
									WHEN b.Product IN ('SB', 'CO', 'NG', 'VS', 'VS2') THEN m.sporttype
									WHEN b.Product IN ('Outright') THEN l.sporttype
									WHEN b.Product IN ('VR') THEN vr.SportType
									ELSE 0
								END,
					BetTeam = CASE
									WHEN b.Product IN ('SB', 'CO', 'NG', 'VS', 'VS2', 'Parlay', 'ParlayVS2') THEN b.betteam
									ELSE ''
								END,
					Hdp1 = CASE
								WHEN b.Product IN ('SB', 'CO', 'NG', 'VS', 'VS2', 'VR', 'Parlay', 'ParlayVS2', 'NG2') THEN b.hdp1
								ELSE 0
							END,
					Hdp2 = CASE
								WHEN b.Product IN ('SB', 'CO', 'VS', 'VS2', 'VR', 'Parlay', 'ParlayVS2', 'NG2') THEN b.hdp2
								ELSE 0
							END,
					OddsType = CASE
									WHEN b.Product IN ('SB', 'CO', 'NG', 'VS', 'VS2') THEN b.oddstype
									ELSE 0
								END,
					Odds = CASE
								WHEN b.Product IN ('SB', 'CO', 'NG', 'VS', 'VS2', 'Outright', 'VR', 'Parlay', 'OneRNG', 'Keno', 'GD', 'NG2', 'ParlayVS2', 
									'Lottery', 'VRG', 'TG', 'I4D', 'PP', 'VS3', 'SBC', 'SLT') THEN b.odds
								ELSE 0
							END,
					MOdds = CASE
								WHEN b.Product IN ('SB', 'CO', 'NG', 'VS', 'VS2', 'Outright', 'VR', 'Parlay', 'ParlayVS2') THEN b.modds
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
										WHEN b.Product IN ('SB', 'CO', 'NG', 'VS', 'VS2') THEN b.liveindicator
										ELSE 0
									END,
					LiveHomeScore = CASE
										WHEN b.Product IN ('SB', 'CO', 'NG', 'VS', 'VS2', 'Outright', 'VR', 'NG2') THEN b.livehomescore
										ELSE 0
									END,
					LiveAwayScore = CASE
										WHEN b.Product IN ('SB', 'CO', 'NG', 'VS', 'VS2', 'Outright', 'VR') THEN b.liveawayscore
										ELSE 0
									END,
					LeagueId = CASE
									WHEN b.Product IN ('SB', 'CO', 'NG', 'VS', 'VS2') THEN m.leagueid
									WHEN b.Product IN ('Outright') THEN o.leagueid
									WHEN b.Product IN ('VR') THEN vr.LeagueID
									ELSE 0
								END,
					MatchId = CASE
									WHEN b.Product IN ('GD') THEN 255
									WHEN b.Product IN ('NG2') THEN b.betdaqid
									WHEN b.Product IN ('SB', 'CO', 'NG', 'VS', 'VS2') THEN m.matchid
									WHEN b.Product IN ('Outright') THEN o.orid
									WHEN b.Product IN ('VR') THEN b.matchid
									ELSE 0
								END,
					MatchCode = CASE
									WHEN b.Product IN ('SB', 'CO', 'NG', 'VS', 'VS2') THEN m.matchcode
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
									WHEN b.Product IN ('NG', 'VS', 'VS2') THEN m.eventdate
									WHEN b.Product IN ('Outright') THEN o.eventdate
									WHEN b.Product IN ('VR') THEN vo.EventDate
									ELSE b.winlostdate
								END,
					HomeId = CASE
								WHEN b.Product IN ('SB', 'CO', 'NG', 'VS', 'VS2') THEN m.homeid
								WHEN b.Product IN ('Outright') THEN o.teamid
								WHEN b.Product IN ('VR') THEN vo.RacerID
								ELSE 0
							END,
					AwayId = CASE
								WHEN b.Product IN ('SB', 'CO', 'NG', 'VS', 'VS2') THEN m.awayid
								ELSE 0
							END,
					IsNeutral = CASE
									WHEN b.Product IN ('SB', 'CO', 'NG', 'VS', 'VS2') THEN ISNULL(m.IsNeutral, 0)
									ELSE 0
								END,
					ShowTime = CASE
									WHEN b.Product IN ('VS', 'VS2') THEN CONVERT(NVARCHAR(50), m.kickofftime)
									WHEN b.Product IN ('SB', 'CO', 'NG') THEN ISNULL(m.showtime, '')
									WHEN b.Product IN ('VR') THEN CONVERT(NVARCHAR(50), vr.EventTime)
									ELSE ''
								END,
					BetCheck = CASE
									WHEN b.Product IN ('SB', 'CO', 'Parlay', 'ParlayVS2', 'GD', 'VRG', 'H5LG', 'SLT') THEN ISNULL(b.betcheck, '')
									WHEN b.Product IN ('Keno') THEN ISNULL(b.comstatus, '')
									WHEN b.Product IN ('CB') THEN ISNULL(bm.betcheck, '')
									ELSE ''
								END,
					ComStatus = CASE WHEN b.comstatus = '1' THEN '1' ELSE '0' END,
					TransDesc = CASE
									WHEN b.Product IN ('SB', 'CO', 'VS2', 'OneRNG', 'CC', 'SG', 'Keno', 'VB', 'NG2', 'FW', 'Lottery', 
										'PP', 'VRG', 'TG', 'I4D', 'PGS', 'JK', 'VS3', 'H5LG', 'SLT', 'HB', 'CG') THEN ISNULL(b.transdesc, '')
									ELSE ''
								END,
					OddsSpread = CASE
									WHEN b.Product IN ('SB', 'CO', 'OneRNG', 'PP', 'SBC') THEN ISNULL(b.oddsspread, 0)
									ELSE 0
								END,
					BetdaqId = CASE
									WHEN b.Product IN ('SB', 'CO') THEN ISNULL(b.betdaqid, -1)
									ELSE -1
								END,
					ExtraInfo = CASE
									WHEN b.Product IN ('SB', 'Parlay', 'NPHP', 'VS3') THEN ISNULL(b.ExtraInfo, '')
									ELSE ''
								END,
					WalletType = CASE
									WHEN b.Product IN ('SB') THEN ISNULL(b.WalletType, 0)
									ELSE 0
								END,
					RefCode = CASE
									WHEN b.Product IN ('SB') THEN ISNULL(b.RefCode, 0)
									ELSE 0
								END
				FROM @Data AS b
					LEFT JOIN bodb_Archive.dbo.match_bk AS m WITH (NOLOCK) ON b.Product IN ('SB', 'CO', 'NG', 'VS', 'VS2') AND b.matchid = m.matchid
					LEFT JOIN bodb_Archive.dbo.bettransm AS bm WITH (NOLOCK) ON b.Product = 'CB' AND bm.refno = b.refno AND bm.bettype = 18001
					LEFT JOIN bodb_Archive.dbo.outright_bk AS o WITH (NOLOCK) ON b.Product IN ('Outright') AND b.matchid = o.orid
					LEFT JOIN dbo.League AS l WITH (NOLOCK) ON b.Product IN ('Outright') AND o.leagueid = l.leagueid
					LEFT JOIN bodb_Archive.dbo.VSOutright_bk AS vo WITH (NOLOCK) ON b.Product IN ('VR') AND b.oddsid = vo.Orid
					LEFT JOIN bodb_Archive.dbo.VSRaceInfo_bk AS vr WITH (NOLOCK) ON b.Product IN ('VR') AND vr.EventID = vo.EventID
				WHERE b.TableID = 3

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
	
				UNION ALL -- Gold Deluxe
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
					bg.transdesc
				FROM @Data AS c
					INNER JOIN bodb_Archive.dbo.bettransg AS bg WITH (NOLOCK) ON c.TransId = bg.refno
				WHERE c.Product = 'GD' AND bg.custid = @CustId
			END
		END
	END

	-- Get currency name
	DECLARE @UGroup		VARCHAR(3),
		@CurrencyName	NVARCHAR(50),
		@Username		NVARCHAR(50)

	SELECT
		@Username = c.username,
		@UGroup = c.ugroup,
		@CurrencyName = ex.currency
	FROM dbo.Customer AS c WITH (NOLOCK)
		INNER JOIN dbo.Exchange AS ex WITH (NOLOCK) ON c.currency = ex.exchangeid
	WHERE c.custid = @CustId

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
		b.BetFrom,
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
		@Username AS Username,
		@UGroup AS UGroup
	FROM @Data AS b
	ORDER BY b.TransId ASC

	SELECT DISTINCT * FROM @DetailData
END
GO
