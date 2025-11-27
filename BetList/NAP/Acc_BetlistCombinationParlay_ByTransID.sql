/*<info serverAlias="DBAGE-bodb02" executers="wsv_nap" viewers="" isFunction="0" isNested="0"></info>*/

ALTER PROCEDURE [dbo].[Acc_BetlistCombinationParlay_ByTransID]
	@TransId		BIGINT,
	@CustId			INT,
	@MoveBetDay		DATETIME,
	@BalanceUpDay	DATETIME,
	@IsParlayBoost	BIT			= 0 OUTPUT
AS

/*
	Created: 20111128@Johnson
	Task: Get details of parlay tickets
	DB: DBAGE.bodb02
	
	Revisions:
		- 20111215@Lukas: correct scomm, acomm, comm
		- 20111229@Jim : remove function :f_GetChoice
		- 20120220@Johnson: support view old data
		- 20120228@Lukas: Get full data of system parlay (related ticket)
		- 20120419@Lukas: Show transid of main ticket for subticket of system parlay
		- 20120927@Johnson: get commstatus column to check double comm losing
		- 20130121@Dan: change linked server DB06 to DBARC
		- 20130514@Elodie: Get odds value
		- 20131216@Kathy: Get data from bettrans14 if @minMatchdate = @MoveBetDay
		- 20141013@Sophia: Get betcheck of bettransm for Sportting Solution
		- 20151210@Kos: Change odds, modds data type from SMALLMONEY to MONEY [Redmine: #48660]
		- 20160120@Kos: Add transdesc to support PH All In One 1.2 new bet types [#Redmine: 50897]
		- 20160411@Kos: Support Combo Parlay [#Redmine: 55282]
		- 20161010@Kos: Add product bet type range for sub tickets [Redmine: #65045]
		- 20170210@Kos: Add DISTINCT to prevent duplicate ticket detail [Redmine: #71007]
		- 20180328@Kos: Increase Transdesc length to 1000 [Redmine: #92841]
		- 20190107@Kos: Support Parlay Changes [#Redmine: 105585]
		- 20190426@Kos: Show Reject status on Parlay sub ticket [Redmine: #112286]
		- 20191114@Kos: Show (N) for neutral match [Redmine: #123772]
		- 20200422@Kos: Support status Delay Payout [Redmine: #132629]
		- 20201028@Kos: Return transdate [Redmine: #144388]
		- 20201123@Kos: Support God Of Fortune [Redmine: #145834]
		- 20210223@Kos: Support Cricket AIO [Redmine: #148962]
		- 20211004@Razor: Extend Data type of IP v6 [Redmine: #90903]
		- 20211025@Razor: Decompress IP on BK range [Redmine: #90903]
		- 20211123@Razor: Check Abnormal Parlay Ticket [Redmine: #163900]
		- 20231004@Kos: Support Parlay Boost [Redmine: #194992]
					- Add output param @IsParlayBoost BIT
					- Return additional columns Odds MONEY, ExtraValue MONEY
		- 20231025@Kos: Hotfix - missing odds for bk range [Redmine: #196042]
		- 20231019@Razor: Return Device Type info [Redmine: #192667]
		- 20240822@Razor: Support Baseball AIO Phase 2 [Redmine: #209584]
		- 20241218@Razor: Support Direct Member [Redmine: #211969]
		- 20251031@Virgil: Support BetBuilder+ Hybrid Parlay [Redmine: #242378]
*/

BEGIN
	SET NOCOUNT ON

	-- Get Sport Bettype Matrix (support Sportsbook only)
	DECLARE @SportBettype TABLE(ProductId TINYINT, Bettype SMALLINT, EventType TINYINT)

	DECLARE @IsTest BIT = 0

	SELECT @IsTest = dbo.f_CheckSPVersion(@@PROCID)

	INSERT INTO @SportBettype (ProductId, Bettype, EventType)
	SELECT ProductID, BetType, EventType
	FROM dbo.f_SportBettypeMatrix_Sel (1, 0, 0, 2, '', '', @IsTest)

	DECLARE @RefNo		BIGINT,
		@CurrencyName	NVARCHAR(50),
		@Status			NVARCHAR(10),
		@minMatchdate	DATETIME,
		@maxMatchdate	DATETIME,
		@WhTicket		TINYINT,-- 1: bettrans, 2: bettrans14, 3: bettrans_bk
		@MainTicketIsMarked BIT;

	SELECT @MainTicketIsMarked = COUNT(1)
	FROM dbo.MarkedTransaction WITH (NOLOCK)
	WHERE transid = @TransId 
		AND MatchId = 29

	-- Check if @transid in bettrans
	SELECT
		@RefNo = b.refno,
		@Status = b.status,
		@CurrencyName = ex.currency,
		@WhTicket = 1
	FROM dbo.bettrans AS b WITH (NOLOCK)
		INNER JOIN dbo.Exchange AS ex WITH (NOLOCK) ON b.currency = ex.exchangeid
	WHERE b.transid = @TransId
		AND b.custid = @CustId
		AND b.bettype = 29

	IF @RefNo IS NULL
	BEGIN
		SELECT
			@RefNo = b.refno,
			@Status = b.status,
			@CurrencyName = ex.currency,
			@WhTicket = 2
		FROM dbo.bettrans14 AS b WITH (NOLOCK)
			INNER JOIN dbo.Exchange AS ex WITH (NOLOCK) ON b.currency = ex.exchangeid
		WHERE b.transid = @TransId
			AND b.custid = @CustId
			AND b.bettype = 29
	END

	IF @RefNo IS NULL
	BEGIN
		SELECT
			@RefNo = b.refno,
			@Status = b.status,
			@CurrencyName = ex.currency,
			@WhTicket = 3
		FROM DBARC.bodb_Archive.dbo.bettrans_bk AS b WITH (NOLOCK)
			INNER JOIN dbo.Exchange AS ex WITH (NOLOCK) ON b.currency = ex.exchangeid
		WHERE b.transid = @TransId
			AND b.custid = @CustId
			AND b.bettype = 29
	END

	DECLARE @tmpBettrans AS TABLE(
		TransId			BIGINT,
		BetId			BIGINT,
		TransDate		DATETIME,
		RefNo			BIGINT,
		WinLostDate		SMALLDATETIME,
		Odds			MONEY,
		Modds			MONEY,
		OddsSpread		MONEY,
		Stake			MONEY,
		Actual_Stake	MONEY,
		WinLost			MONEY,
		PlayerComm		MONEY,
		Status			VARCHAR(20),
		ComStatus		NVARCHAR(20),
		BetTeam			VARCHAR(20),
		Ip				VARCHAR(45),
		SPositionTaking	SMALLMONEY,
		MPositionTaking	SMALLMONEY,
		APositionTaking	SMALLMONEY,
		SWinLost		MONEY,
		MWinLost		MONEY,
		AWinLost		MONEY,
		SDiscount		SMALLMONEY,
		ADiscount		SMALLMONEY,
		Discount		SMALLMONEY,
		SComm			MONEY,
		AComm			MONEY,
		Comm			MONEY,
		Hdp1			SMALLMONEY,
		Hdp2			SMALLMONEY,
		BetCheck		NVARCHAR(50),
		TransDesc		NVARCHAR(1000),
		ExtraInfo		VARCHAR(1000),
		DeviceType		TINYINT,
		--for generating combination parlays if not in BetParlayResult
		N				TINYINT,		-- Number of selection
		Bitmap			INT				-- Combination bitmap
	)

	DECLARE @parlay_base AS TABLE (
		TransId				BIGINT,
		RefNo				BIGINT,
		TransDate			DATETIME,
		WinLostDate			SMALLDATETIME,
		BetType				INT,
		HomeId				INT,
		AwayId				INT,
		Hdp1				SMALLMONEY,
		Hdp2				SMALLMONEY,
		Odds				MONEY,
		BetTeam				VARCHAR(20),
		Status				NVARCHAR(10),
		SettlementStatus	TINYINT,
		LiveHomeScore		INT,
		LiveAwayScore		INT,
		LiveIndicator		BIT,
		LeagueId			INT,
		SportType			INT,
		IsNeutral			BIT,
		MatchId				INT,
		MatchCode			VARCHAR(50),
		EventDate			DATETIME,
		MatchDate			DATETIME,
		BetCheck			NVARCHAR(50),
		TransDesc			NVARCHAR(1000),
		SetStake			MONEY,
		--for generating combination parlays
		RN					TINYINT,	-- set No. for selection in the combination
		Cnt					TINYINT,	-- total selection count, base on bettransm/14
		bCnt				TINYINT		-- total selection count, stored in bettrans
	)

	DECLARE @tmpResults AS TABLE(
		WinLostDate	DATETIME,
		Serial		BIGINT,
		Odds		MONEY,
		MOdds		MONEY,
		Stake		MONEY,
		WinLost		MONEY,
		StatusId	INT,
		Status		VARCHAR(20),
		ExtraValue	MONEY
	)

	DECLARE @betParlayDetail TABLE (
		RefNo	BIGINT,
		Serial	INT,
		MatchId	INT
	)

	DECLARE @tmpMatch AS TABLE(
		Serial		BIGINT,
		HomeId		INT,
		AwayId		INT,
		IsNeutral	BIT
	)

	-- Get bettransm data
	INSERT INTO @parlay_base (
		TransId,
		RefNo,
		TransDate,
		WinLostDate,
		BetType,
		HomeId,
		AwayId,
		Hdp1,
		Hdp2,
		Odds,
		BetTeam,
		Status,
		SettlementStatus,
		LiveHomeScore,
		LiveAwayScore,
		LiveIndicator,
		LeagueId,
		SportType,
		IsNeutral,
		MatchId,
		MatchCode,
		EventDate,
		MatchDate,
		BetCheck,
		TransDesc,
		SetStake)
	SELECT
		bm.transid,
		bm.refno,
		bm.transdate,
		bm.winlostdate,
		bm.bettype,
		m.homeid,
		m.awayid,
		bm.hdp1,
		bm.hdp2,
		bm.odds,
		bm.betteam,
		CASE
			WHEN @Status = 'Void' THEN ''
			WHEN @Status = 'Reject' AND bm.status <> 'Reject' THEN ''
			WHEN bm.status = 'running' AND ISNULL(bm.SecAcceptFlag, 0) = 1 AND ISNULL(bm.checktime, CURRENT_TIMESTAMP) > CURRENT_TIMESTAMP THEN 'waiting'
			WHEN bm.status = 'WON' AND ISNULL(bm.statuswinlost, 0) = 1 THEN 'Half Won'
			WHEN bm.status = 'LOSE' AND ISNULL(bm.statuswinlost, 0) = 3 THEN 'Half Lose'
			ELSE bm.status
		END AS status,
		CASE 
			WHEN bm.status IN ('WON','LOSE','DRAW') AND @MainTicketIsMarked = 1 THEN 255
			ELSE ISNULL(m.SettlementStatus, 0)
		END AS SettlementStatus,
		bm.livehomescore,
		bm.liveawayscore,
		bm.liveindicator,
		m.leagueid,
		m.sporttype,
		m.IsNeutral,
		CASE
			WHEN m.sporttype IN (8, 50) AND m.ChildMatchType = 200 THEN pm.matchid
			ELSE m.matchid
		END AS MatchId,
		CASE
			WHEN m.sporttype IN (8, 50) AND m.ChildMatchType = 200 THEN pm.matchcode
			ELSE m.matchcode
		END AS MatchCode,
		CASE
			WHEN m.sporttype IN (8, 50) AND m.ChildMatchType = 200 THEN pm.GlobalShowTime
			ELSE m.GlobalShowTime
		END AS EventDate,
		bm.matchdate,
		ISNULL(bm.betcheck, '') AS BetCheck,
		ISNULL(bm.transdesc, '') AS TransDesc,
		bm.stake
	FROM dbo.bettransm AS bm WITH (NOLOCK)
		INNER JOIN dbo.match AS m WITH (NOLOCK) ON bm.matchid = m.matchid
		LEFT JOIN dbo.match AS pm WITH (NOLOCK)
			ON pm.matchid = m.ParentID
			AND m.sporttype IN (8, 50)
			AND m.ChildMatchType = 200
		INNER JOIN @SportBettype AS sbt ON bm.bettype = sbt.Bettype
	WHERE bm.refno = @RefNo AND bm.custid = @CustId

	UNION

	SELECT
		bm.transid,
		bm.refno,
		bm.transdate,
		bm.winlostdate,
		bm.bettype,
		m.homeid,
		m.awayid,
		bm.hdp1,
		bm.hdp2,
		bm.odds,
		bm.betteam,
		CASE
			WHEN @Status = 'Void' THEN ''
			WHEN @Status = 'Reject' AND bm.status <> 'Reject' THEN ''
			WHEN bm.status = 'WON' AND ISNULL(bm.statuswinlost, 0) = 1 THEN 'Half Won'
			WHEN bm.status = 'LOSE' AND ISNULL(bm.statuswinlost, 0) = 3 THEN 'Half Lose'
			ELSE bm.status
		END AS status,
		0 AS SettlementStatus,
		bm.livehomescore,
		bm.liveawayscore,
		bm.liveindicator,
		m.leagueid,
		m.sporttype,
		m.IsNeutral,
		CASE
			WHEN m.sporttype IN (8, 50) AND m.ChildMatchType = 200 THEN ISNULL(pm14.matchid, pm.matchid)
			ELSE m.matchid
		END AS MatchId,
		CASE
			WHEN m.sporttype IN (8, 50) AND m.ChildMatchType = 200 THEN ISNULL(pm14.matchcode, pm.matchcode)
			ELSE m.matchcode
		END AS MatchCode,
		CASE
			WHEN m.sporttype IN (8, 50) AND m.ChildMatchType = 200 THEN ISNULL(pm14.GlobalShowTime, pm.GlobalShowTime)
			ELSE m.GlobalShowTime
		END AS EventDate,
		bm.matchdate,
		ISNULL(bm.betcheck, '') AS BetCheck,
		ISNULL(bm.transdesc, '') AS TransDesc,
		bm.stake
	FROM dbo.bettransm14 AS bm WITH (NOLOCK)
		INNER JOIN dbo.match14 AS m WITH (NOLOCK) ON bm.matchid = m.matchid
		LEFT JOIN dbo.match14 AS pm14 WITH (NOLOCK)
			ON pm14.matchid = m.ParentID
			AND m.sporttype IN (8, 50)
			AND m.ChildMatchType = 200
		LEFT JOIN dbo.match AS pm WITH (NOLOCK)
			ON pm.matchid = m.ParentID
			AND m.sporttype IN (8, 50)
			AND m.ChildMatchType = 200
		INNER JOIN @SportBettype AS sbt ON bm.bettype = sbt.Bettype
	WHERE bm.refno = @RefNo

	UNION

	SELECT
		bm.transid,
		bm.refno,
		bm.transdate,
		bm.winlostdate,
		bm.bettype,
		m.homeid,
		m.awayid,
		bm.hdp1,
		bm.hdp2,
		bm.odds,
		bm.betteam,
		CASE
			WHEN @Status = 'Void' THEN ''
			WHEN @Status = 'Reject' AND bm.status <> 'Reject' THEN ''
			WHEN bm.status = 'WON' AND ISNULL(bm.statuswinlost, 0) = 1 THEN 'Half Won'
			WHEN bm.status = 'LOSE' AND ISNULL(bm.statuswinlost, 0) = 3 THEN 'Half Lose'
			ELSE bm.status
		END AS status,
		0 AS SettlementStatus,
		bm.livehomescore,
		bm.liveawayscore,
		bm.liveindicator,
		m.leagueid,
		m.sporttype,
		m.isNeutral,
		CASE
			WHEN m.sporttype IN (8, 50) AND m.ChildMatchType = 200 THEN ISNULL(pmbk.matchid, ISNULL(pm14.matchid, pm.matchid))
			ELSE m.matchid
		END AS MatchId,
		CASE
			WHEN m.sporttype IN (8, 50) AND m.ChildMatchType = 200 THEN ISNULL(pmbk.matchcode, ISNULL(pm14.matchcode, pm.matchcode))
			ELSE m.matchcode
		END AS MatchCode,
		CASE
			WHEN m.sporttype IN (8, 50) AND m.ChildMatchType = 200 THEN ISNULL(pmbk.GlobalShowTime, ISNULL(pm14.GlobalShowTime, pm.GlobalShowTime))
			ELSE m.GlobalShowTime
		END AS EventDate,
		bm.matchdate,
		ISNULL(bm.betcheck, '') AS BetCheck,
		ISNULL(bm.transdesc, '') AS TransDesc,
		bm.stake
	FROM DBARC.bodb_Archive.dbo.bettransm AS bm WITH (NOLOCK)
		INNER JOIN DBARC.bodb_Archive.dbo.match_bk AS m WITH (NOLOCK) ON bm.matchid = m.matchid
		LEFT JOIN DBARC.bodb_Archive.dbo.match_bk AS pmbk WITH (NOLOCK)
			ON pmbk.matchid = m.ParentID
			AND m.sporttype IN (8, 50)
			AND m.ChildMatchType = 200
		LEFT JOIN dbo.match14 AS pm14 WITH (NOLOCK)
			ON pm14.matchid = m.ParentID
			AND m.sporttype IN (8, 50)
			AND m.ChildMatchType = 200
		LEFT JOIN dbo.match AS pm WITH (NOLOCK)
			ON pm.matchid = m.ParentID
			AND m.sporttype IN (8, 50)
			AND m.ChildMatchType = 200
		INNER JOIN @SportBettype AS sbt ON bm.bettype = sbt.Bettype
	WHERE bm.refno = @RefNo

	SELECT	@minMatchdate = MIN(matchdate),
			@maxMatchdate = MAX(matchdate)
	FROM @parlay_base

	-- Get bettrans and BetParlayResult data
	IF EXISTS (SELECT 1 FROM @parlay_base WHERE MatchDate < @BalanceUpDay)		-- bettrans_bk
	BEGIN
		INSERT INTO @tmpBettrans (
			TransId, BetId, TransDate, RefNo, WinLostDate, Odds, Modds, OddsSpread, Stake, Actual_Stake, WinLost, PlayerComm, Status,
			ComStatus, BetTeam, Ip, SPositionTaking, MPositionTaking, APositionTaking, SWinLost, MWinLost, AWinLost,
			SDiscount, ADiscount, Discount,	SComm, AComm, Comm, Hdp1, Hdp2, BetCheck, TransDesc, ExtraInfo, DeviceType, N, Bitmap
		)
		SELECT
			bk.transid,
			bk.betid,
			bk.transdate,
			bk.refno,
			bk.winlostdate,
			bk.odds,
			bk.modds,
			bk.oddsspread,
			bk.stake,
			bk.actual_stake,
			CASE
				WHEN bk.statusid NOT IN (0,1) THEN bk.winlost - bk.actual_stake 
				ELSE bk.winlost
			END AS winlost,
			bk.playercomm,
			bk.status,
			CASE WHEN bk.comstatus = '1' THEN 1 ELSE 0 END AS comstatus,
			bk.betteam,
			dp.ip,
			bk.spositiontaking,
			bk.mpositiontaking,
			bk.apositiontaking,
			bk.swinlost,
			bk.mwinlost,
			bk.awinlost,
			bk.sdiscount,
			CASE
				WHEN bk.mrecommend = -4 THEN 0
				ELSE bk.adiscount
			END,
			CASE
				WHEN bk.recommend IN (-3, -4) THEN 0
				ELSE bk.discount
			END,
			bk.scomm - bk.acomm,
			bk.acomm - bk.comm,
			bk.comm - bk.playercomm,
			bk.hdp1,
			bk.hdp2,
			ISNULL(bk.betcheck, '') AS BetCheck,
			IIF(bk.bettype = 29 AND bk.OddsSpread = 3, ISNULL(bk.transdesc, ''), '') AS TransDesc,
			ISNULL(bk.ExtraInfo, '') AS ExtraInfo,
			bk.DeviceType,
			CASE
				WHEN bk.betcheck IS NULL THEN LEN(bk.betteam)				-- old Parlay tickets
				WHEN bk.bettype = 29 AND bk.oddsspread = 3 THEN bk.betid	-- Hybrid Parlay tickets
				ELSE bk.hdp2												-- new Parlay tickets
			END AS N,
			CASE
				WHEN bk.betcheck IS NULL THEN CONVERT(INT, bk.hdp2)	-- old Parlay tickets
				ELSE CONVERT(INT, bk.betteam)						-- new Parlay tickets
			END AS Bitmap
		FROM DBARC.bodb_archive.dbo.bettrans_bk AS bk WITH (NOLOCK)
			CROSS APPLY dbo.f_IP_Decompress(bk.Ip) AS dp
		WHERE bk.custid = @CustId
			AND bk.transid = @TransId
			AND bk.bettype = 29

		INSERT INTO @tmpResults (
			WinLostDate,
			Serial,
			Odds,
			Modds,
			Stake,
			WinLost,
			StatusId,
			ExtraValue)
		SELECT
			ba.winlostdate,
			ba.serial,
			ba.odds,
			ba.modds,
			ba.stake,
			ba.winlost,
			ba.statusid,
			ba.ExtraValue
		FROM DBARC.bodb_Archive.dbo.betparlayresult AS ba WITH (NOLOCK)
		WHERE ba.refno = @RefNo
	END

	IF EXISTS (SELECT 1 FROM @parlay_base WHERE MatchDate BETWEEN @BalanceUpDay AND @MoveBetDay)		-- bettrans14
	BEGIN
		INSERT INTO @tmpBettrans (
			TransId, BetId, TransDate, RefNo, WinLostDate, Odds, Modds, OddsSpread, Stake, Actual_Stake, WinLost, PlayerComm, Status,
			ComStatus, BetTeam, Ip, SPositionTaking, MPositionTaking, APositionTaking, SWinLost, MWinLost, AWinLost,
			SDiscount, ADiscount, Discount,	SComm, AComm, Comm, Hdp1, Hdp2, BetCheck, TransDesc, ExtraInfo, DeviceType, N, Bitmap
		)
		SELECT
			b14.transid,
			b14.betid,
			b14.transdate,
			b14.refno,
			b14.winlostdate,
			b14.odds,
			b14.modds,
			b14.oddsspread,
			b14.stake,
			b14.actual_stake,
			CASE
				WHEN b14.statusID NOT IN (0, 1) THEN b14.winlost - b14.actual_stake
				ELSE b14.winlost
			END AS winlost,
			b14.playercomm,
			b14.status,
			CASE WHEN b14.comstatus = '1' THEN 1 ELSE 0 END AS comstatus,
			b14.betteam,
			b14.ip,
			b14.spositiontaking,
			b14.mpositiontaking,
			b14.apositiontaking,
			b14.swinlost,
			b14.mwinlost,
			b14.awinlost,
			b14.sdiscount,
			CASE
				WHEN b14.mrecommend = -4 THEN 0
				ELSE b14.adiscount
			END,
			CASE
				WHEN b14.recommend IN (-3, -4) THEN 0
				ELSE b14.discount
			END,
			b14.scomm - b14.acomm,
			b14.acomm - b14.comm,
			b14.comm - b14.playercomm,
			b14.hdp1,
			b14.hdp2,
			ISNULL(b14.betcheck, '') AS BetCheck,
			IIF(b14.bettype = 29 AND b14.OddsSpread = 3, ISNULL(b14.transdesc, ''), '') AS TransDesc,
			ISNULL(b14.ExtraInfo, '') AS ExtraInfo,
			b14.DeviceType,
			CASE
				WHEN b14.betcheck IS NULL THEN LEN(b14.betteam)				-- old Parlay tickets
				WHEN b14.bettype = 29 AND b14.oddsspread = 3 THEN b14.betid	-- Hybrid Parlay tickets
				ELSE b14.hdp2												-- new Parlay tickets
			END AS N,
			CASE
				WHEN b14.betcheck IS NULL THEN CONVERT(INT, b14.hdp2)	-- old Parlay tickets
				ELSE CONVERT(INT, b14.betteam)						-- new Parlay tickets
			END AS Bitmap
		FROM dbo.bettrans14 AS b14 WITH (NOLOCK)
		WHERE b14.custid = @CustId
			AND b14.transid = @TransId
			AND b14.bettype = 29
	END

	IF EXISTS (SELECT 1 FROM @parlay_base WHERE MatchDate > @MoveBetDay)		-- bettrans
	BEGIN
		INSERT INTO @tmpBettrans (
			TransId, BetId, TransDate, RefNo, WinLostDate, Odds, Modds, OddsSpread, Stake, Actual_Stake, WinLost, PlayerComm, Status,
			ComStatus, BetTeam, Ip, SPositionTaking, MPositionTaking, APositionTaking, SWinLost, MWinLost, AWinLost,
			SDiscount, ADiscount, Discount,	SComm, AComm, Comm, Hdp1, Hdp2, BetCheck, TransDesc, ExtraInfo, DeviceType, N, Bitmap
		)
		SELECT
			b.transid,
			b.betid,
			b.transdate,
			b.refno,
			b.winlostdate,
			b.odds,
			b.modds,
			b.oddsspread,
			b.stake,
			b.actual_stake,
			b.winlost - b.actual_stake AS winlost,
			b.playercomm,
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
			CASE WHEN b.comstatus = '1' THEN 1 ELSE 0 END AS comstatus,
			b.betteam,
			b.ip,
			b.spositiontaking,
			b.mpositiontaking,
			b.apositiontaking,
			b.swinlost,
			b.mwinlost,
			b.awinlost,
			b.sdiscount,
			CASE
				WHEN b.mrecommend = -4 THEN 0
				ELSE b.adiscount
			END,
			CASE
				WHEN b.recommend IN (-3, -4) THEN 0
				ELSE b.discount
			END,
			b.scomm - b.acomm,
			b.acomm - b.comm,
			b.comm - b.playercomm,
			b.hdp1,
			b.hdp2,
			ISNULL(b.betcheck, '') AS BetCheck,
			IIF(b.bettype = 29 AND b.OddsSpread = 3, ISNULL(b.transdesc, ''), '') AS TransDesc,
			ISNULL(b.ExtraInfo, '') AS ExtraInfo,
			b.DeviceType,
			CASE
				WHEN b.betcheck IS NULL THEN LEN(betteam)				-- old Parlay tickets
				WHEN b.bettype = 29 AND b.oddsspread = 3 THEN b.betid	-- Hybrid Parlay tickets
				ELSE b.hdp2												-- new Parlay tickets
			END AS N,
			CASE
				WHEN b.betcheck IS NULL THEN CONVERT(INT, b.hdp2)	-- old Parlay tickets
				ELSE CONVERT(INT, b.betteam)						-- new Parlay tickets
			END AS Bitmap
		FROM dbo.bettrans AS b WITH (NOLOCK)
		WHERE b.custid = @CustId
			AND b.transid = @TransId
			AND b.bettype = 29
	END
	
	INSERT INTO @tmpResults (
		WinLostDate,
		Serial,
		Odds,
		Modds,
		Stake,
		WinLost,
		StatusId,
		ExtraValue)
	SELECT 
		b.winlostdate,
		b.Serial,
		b.Odds,
		b.mOdds,
		b.stake,
		b.winlost,
		b.statusid,
		b.ExtraValue
	FROM dbo.betparlayresult AS b WITH (NOLOCK)
	WHERE refno = @RefNo AND serial NOT IN (SELECT serial FROM @tmpResults)

	IF NOT EXISTS (SELECT TOP 1 1 FROM @tmpResults)
	BEGIN
		DECLARE @betParlayResult TABLE (
			RefNo		BIGINT,
			Serial		INT,
			WinLostDate SMALLDATETIME,
			Stake		MONEY
		)

		;WITH sub AS (SELECT ROW_NUMBER() OVER (ORDER BY matchid ASC) RN, matchid FROM @parlay_base)
		UPDATE pb
		SET RN = sub.RN
		FROM sub AS sub
			INNER JOIN @parlay_base AS pb ON sub.matchid = pb.matchid

		-- prepare N
		;WITH sub AS (SELECT COUNT(*) AS cnt FROM @parlay_base)
		UPDATE pb
		SET Cnt = (SELECT TOP 1 sub.cnt FROM sub), 
			bCnt = t.N
		FROM @parlay_base AS pb
		INNER JOIN @tmpBettrans AS t ON pb.RefNo = t.RefNo;

		IF NOT EXISTS(SELECT 1 FROM @parlay_base WHERE cnt <> bCnt)
		BEGIN
			INSERT INTO @betParlayDetail (RefNo, Serial, MatchId)
			SELECT
				pb.RefNo,
				rc.Serial,
				pb.MatchId
			FROM
				@parlay_base AS pb
				INNER JOIN @tmpBettrans AS tb ON pb.refno = tb.refno
				INNER JOIN dbo.RefCombinationSet AS rcs WITH (NOLOCK) ON pb.CNT = rcs.N AND (tb.Bitmap & rcs.bitmapR) > 0
				INNER JOIN dbo.RefCombination AS rc WITH (NOLOCK) ON rcs.N = rc.N AND rcs.R = rc.R AND pb.RN = rc.seq

			;WITH ParlayStake AS (SELECT refno, RN, setstake FROM @parlay_base)
			INSERT INTO @betParlayResult (RefNo, Serial, WinLostDate, Stake)
			SELECT DISTINCT 
				tb.RefNo,
				rc.Serial,
				tb.WinLostDate,
				ps.SetStake
			FROM
				@tmpBettrans AS tb
				INNER JOIN dbo.RefCombinationSet AS rcs WITH (NOLOCK) ON tb.N = rcs.N AND (tb.bitmap & rcs.bitmapR) > 0
				INNER JOIN dbo.RefCombination AS rc WITH (NOLOCK) ON rcs.N = rc.N AND rcs.R = rc.R
				INNER JOIN ParlayStake AS ps ON ps.refno = tb.RefNo AND ps.RN = rc.R

			INSERT INTO @tmpResults (WinLostDate, Serial, Odds, MOdds, Stake, WinLost, StatusId, Status, ExtraValue)
			SELECT
				WinLostDate,
				Serial,
				0 AS Odds,
				0 AS Modds,
				Stake,
				0 AS WinLost,
				0 AS StatusId,
				'running' AS Status,
				'' AS ExtraValue
			FROM @betParlayResult
			
			INSERT INTO @tmpMatch (Serial, HomeId, AwayId, IsNeutral)
			SELECT
				p.serial,
				m.homeid,
				m.awayid,
				m.IsNeutral
			FROM @tmpResults AS p
				INNER JOIN @betParlayDetail AS b ON p.Serial = b.Serial
				INNER JOIN dbo.match AS m WITH (NOLOCK) ON b.matchid = m.matchid
		END
	END
	ELSE
	BEGIN
		-- Generate betparlay detail
		;WITH sub AS 
		(
			SELECT ROW_NUMBER() OVER (ORDER BY matchid ASC) RN, matchid FROM @parlay_base
		)
		UPDATE pb
		SET RN = sub.RN
		FROM sub AS sub
			INNER JOIN @parlay_base AS pb ON sub.matchid = pb.matchid

		-- Prepare N
		;WITH sub AS (SELECT COUNT(*) AS cnt FROM @parlay_base)
		UPDATE pb
		SET Cnt = (SELECT TOP 1 sub.cnt FROM sub), 
			bCnt = t.N
		FROM @parlay_base AS pb
		INNER JOIN @tmpBettrans AS t ON pb.RefNo = t.RefNo;
		
		IF NOT EXISTS(SELECT 1 FROM @parlay_base WHERE cnt <> bCnt)
		BEGIN
			INSERT INTO @betParlayDetail (RefNo, Serial, MatchId)
			SELECT 
				pb.RefNo,
				rc.Serial,
				pb.MatchId
			FROM
				@parlay_base AS pb
				INNER JOIN @tmpBettrans AS tb ON pb.refno = tb.refno
				INNER JOIN dbo.RefCombinationSet AS rcs WITH (NOLOCK) ON pb.CNT = rcs.N AND (tb.Bitmap & rcs.bitmapR) > 0
				INNER JOIN dbo.RefCombination AS rc WITH (NOLOCK) ON rcs.N = rc.N AND rcs.R = rc.R AND pb.RN = rc.seq
		END

		-- Get homeid, awayid
		IF @MinMatchdate < @BalanceUpday
		BEGIN
			INSERT INTO @tmpMatch (Serial, HomeId, AwayId, IsNeutral)
			SELECT
				p.serial,
				m.homeid,
				m.awayid,
				m.IsNeutral
			FROM @tmpResults AS p
				INNER JOIN @betParlayDetail AS b ON p.Serial = b.Serial
				INNER JOIN DBARC.bodb_Archive.dbo.match_bk AS m WITH (NOLOCK) ON b.matchid = m.matchid
		END

		IF @MinMatchdate <= @MoveBetDay
		BEGIN
			INSERT INTO @tmpMatch (Serial, HomeId, AwayId, IsNeutral)
			SELECT
				p1.serial,
				m1.homeid,
				m1.awayid,
				m1.IsNeutral
			FROM @tmpResults AS p1
				INNER JOIN @betParlayDetail AS b1 ON p1.Serial = b1.Serial
				INNER JOIN dbo.match14 AS m1 WITH (NOLOCK) ON b1.matchid = m1.matchid
		END

		IF @MaxMatchdate > @MoveBetDay
		BEGIN
			INSERT INTO @tmpMatch (Serial, HomeId, AwayId, IsNeutral)
			SELECT
				p2.serial,
				m2.homeid,
				m2.awayid,
				m2.IsNeutral
			FROM @tmpResults AS p2
				INNER JOIN @betParlayDetail AS b2 ON p2.Serial = b2.Serial
				INNER JOIN dbo.match AS m2 WITH (NOLOCK) ON b2.matchid = m2.matchid
		END
	END

	DECLARE
		@WinLost		MONEY,
		@Discount		MONEY,
		@OriginalOdds	MONEY,
		@FinalOdds		MONEY,
		@BetTeam		NVARCHAR(10),
		@BoostRate		MONEY

	SELECT
		@WinLost = WinLost,
		@Discount = CASE
						WHEN ExtraInfo LIKE '%p1%' THEN
							ISNULL(CAST(('<xml>' + ExtraInfo + '</xml>') AS XML).value('data(/xml/p1/@d)[1]','MONEY'), 0)
						ELSE 0
					END,
		@BetTeam = BetTeam,
		@IsParlayBoost = CASE
							WHEN BetTeam = '1'
								AND OddsSpread = 2
								AND Status = 'Won'
								AND ISNULL(CAST(('<xml>' + ExtraInfo + '</xml>') AS XML).value('data(/xml/p1/@bba)[1]','MONEY'), 0) > 0 THEN 1
							WHEN BetTeam = '1'
								AND OddsSpread = 2
								AND Status IN ('Running', 'Waiting') THEN 1
							ELSE 0
						END,
		@BoostRate = CASE
						WHEN BetTeam = '1' AND OddsSpread = 2
							THEN ISNULL(CAST(('<xml>' + ExtraInfo + '</xml>') AS XML).value('data(/xml/p1/@bbp)[1]','MONEY'), 0)
						ELSE 0
					END
	FROM @tmpBettrans

	-- Get original odds for Mix Parlay
	IF @BetTeam = '1'
	BEGIN
		IF @Status IN ('Running', 'Waiting')
		BEGIN
			IF EXISTS (SELECT 1 FROM dbo.BetParlayDetail WHERE RefNo = @RefNo)
			BEGIN
				SELECT
					@OriginalOdds = dbo.PRODUCT(odds),
					@FinalOdds = dbo.PRODUCT(odds) * (@BoostRate + 1) - @BoostRate
				FROM dbo.BetParlayDetail WITH (NOLOCK)
				WHERE RefNo = @RefNo
				GROUP BY RefNo
			END
			ELSE
			BEGIN
				SELECT
					@OriginalOdds = dbo.PRODUCT(odds),
					@FinalOdds = dbo.PRODUCT(odds) * (@BoostRate + 1) - @BoostRate
				FROM dbo.bettransm WITH (NOLOCK)
				WHERE RefNo = @RefNo
				GROUP BY RefNo
			END

			UPDATE @tmpBettrans
			SET
				Odds = @OriginalOdds,
				Modds = @FinalOdds
		END
		ELSE IF @WhTicket IN (1, 2)
		BEGIN
			UPDATE b
			SET
				b.Odds = bpr.Odds,
				b.Modds = bpr.mOdds,
				b.TransDesc = IIF(b.OddsSpread = 3, b.TransDesc, CONVERT(VARCHAR(20), ISNULL(bpr.ExtraValue, '')))
			FROM @tmpBettrans AS b
				INNER JOIN dbo.BetParlayResult AS bpr WITH (NOLOCK) ON bpr.RefNo = b.RefNo
		END
		ELSE
		BEGIN
			UPDATE b
			SET
				b.Odds = bpr.Odds,
				b.Modds = bpr.mOdds,
				b.TransDesc = IIF(b.OddsSpread = 3, b.TransDesc, CONVERT(VARCHAR(20), ISNULL(bpr.ExtraValue, '')))
			FROM @tmpBettrans AS b
				INNER JOIN DBARC.bodb_Archive.dbo.BetParlayResult AS bpr WITH (NOLOCK) ON bpr.RefNo = b.RefNo
		END
	END


	SELECT DISTINCT
		TransId,
		TransDate,
		RefNo,
		WinLostDate,
		Odds,
		Modds,
		OddsSpread,
		Stake,
		Actual_Stake,
		WinLost,
		PlayerComm,
		Status,
		ComStatus,
		BetTeam,
		Ip,
		SPositionTaking,
		MPositionTaking,
		APositionTaking,
		SWinLost,
		MWinLost,
		AWinLost,
		SDiscount,
		ADiscount,
		Discount,
		SComm,
		AComm,
		Comm,
		Hdp1,
		Hdp2,
		BetCheck,
		TransDesc,
		ExtraInfo,
		DeviceType
	FROM @tmpBettrans

	SELECT DISTINCT
		TransId,
		RefNo,
		TransDate,
		WinLostDate,
		BetType,
		SetStake AS Stake,
		@CurrencyName AS Currency,
		HomeId,
		AwayId,
		Hdp1,
		Hdp2,
		Odds,
		BetTeam,
		Status,
		SettlementStatus,
		LiveHomeScore,
		LiveAwayScore,
		LiveIndicator,
		LeagueId,
		SportType,
		IsNeutral,
		MatchId,
		MatchCode,
		EventDate,
		BetCheck,
		TransDesc
	FROM @Parlay_Base

	SELECT
		WinLostDate,
		Serial,
		CASE
			WHEN @Status IN ('Running', 'Waiting') THEN @OriginalOdds
			ELSE Odds
		END AS Odds,
		CASE
			WHEN @Status IN ('Running', 'Waiting') AND @IsParlayBoost = 0 THEN @OriginalOdds
			WHEN @Status IN ('Running', 'Waiting') AND @IsParlayBoost = 1 THEN @FinalOdds
			WHEN @BetTeam = '1' AND StatusId = 113 AND MOdds = 0 THEN Odds
			ELSE MOdds
		END AS Modds,
		Stake,
		StatusId,
		CASE
			WHEN StatusId NOT IN (0, 1) THEN
				CASE
					WHEN @Discount > 0 THEN @WinLost
					ELSE WinLost - Stake
				END
			ELSE WinLost
		END AS WinLost,
		CASE StatusId
			WHEN 101 THEN 'REJECT'
			WHEN 102 THEN 'VOID'
			WHEN 103 THEN 'REFUND'
			WHEN 111 THEN 'DRAW'
			WHEN 112 THEN 'WON'
			WHEN 113 THEN 'LOSE'
			WHEN 0 THEN 'RUNNING'
			ELSE ''
		END AS status,
		CASE
			WHEN @Status IN ('Running', 'Waiting') AND @IsParlayBoost = 1 THEN @BoostRate
			ELSE ExtraValue
		END AS ExtraValue
	FROM ( SELECT DISTINCT 
				WinLostDate,
				Serial,
				Odds,
				MOdds,
				Stake,
				WinLost,
				StatusId,
				Status,
				ExtraValue 
			FROM @tmpResults 
		) AS tmp
	ORDER BY CASE WHEN statusid NOT IN (0, 1) THEN winlostdate ELSE '' END ASC

	SELECT DISTINCT 
			Serial,
			HomeId,
			AwayId,
			IsNeutral
	FROM @tmpMatch
END
GO
