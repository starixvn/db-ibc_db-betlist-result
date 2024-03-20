/*<info serverAlias="DBSIG-bodb02" executers="wsv_nap" viewers="" isFunction="0" isNested="0"></info>*/

ALTER PROCEDURE [dbo].[SiteDB_Acc_BetList_Parlay_SelByRefNo]
	@TransId		BIGINT,
	@CustId			INT,
	@MoveBetDay		DATETIME,
	@BalanceUpDay	DATETIME,
	@IsParlayBoost	BIT			= 0 OUTPUT
AS

/*
	Created by: 20220729@Kos
	Task: NAP- Left Panel => Member Bet List => Parlay
	DB: DBSIG.bodb02

	Revisions:
		- 20220819@Kos: Scale out DBTRANS [Redmine: #175253]
		- 20231004@Kos: Support Parlay Boost [Redmine: #194992]
					- Add output param @IsParlayBoost BIT
					- Return additional columns Odds MONEY, ExtraValue MONEY
		- 20231025@Kos: Hotfix - missing odds for bk range [Redmine: #196042]
		- 20231019@Razor: Return Device Type info [Redmine: #192667]
*/

BEGIN
	SET NOCOUNT ON

	-- Get Sport Bettype Matrix (support Sportsbook only)
	DECLARE @SportBettype TABLE(ProductId TINYINT, Bettype SMALLINT, EventType TINYINT)

	DECLARE @IsTest BIT = 0

	SELECT @IsTest = dbo.f_CheckSPVersion(@@PROCID)

	INSERT INTO @SportBettype
	SELECT ProductID, BetType, EventType
	FROM dbo.f_SportBettypeMatrix_Sel (1, 0, 0, 2, '', '', @IsTest)

	DECLARE @RefNo		BIGINT,
		@CurrencyName	NVARCHAR(50),
		@Status			NVARCHAR(10),
		@minMatchdate	DATETIME,
		@maxMatchdate	DATETIME,
		@WhTicket		TINYINT,-- 1: bettrans, 2: bettrans14, 3: bettrans_bk
		@MainTicketIsMarked BIT

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
		INNER JOIN CustDB.dbo.Exchange AS ex WITH (NOLOCK) ON b.currency = ex.exchangeid
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
			INNER JOIN CustDB.dbo.Exchange AS ex WITH (NOLOCK) ON b.currency = ex.exchangeid
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
			INNER JOIN CustDB.dbo.Exchange AS ex WITH (NOLOCK) ON b.currency = ex.exchangeid
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
			WHEN m.sporttype = 50 AND m.ChildMatchType = 200 THEN pm.matchid
			ELSE m.matchid
		END AS MatchId,
		CASE
			WHEN m.sporttype = 50 AND m.ChildMatchType = 200 THEN pm.matchcode
			ELSE m.matchcode
		END AS MatchCode,
		CASE
			WHEN m.sporttype = 50 AND m.ChildMatchType = 200 THEN pm.GlobalShowTime
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
			AND m.sporttype = 50
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
			WHEN m.sporttype = 50 AND m.ChildMatchType = 200 THEN ISNULL(pm14.matchid, pm.matchid)
			ELSE m.matchid
		END AS MatchId,
		CASE
			WHEN m.sporttype = 50 AND m.ChildMatchType = 200 THEN ISNULL(pm14.matchcode, pm.matchcode)
			ELSE m.matchcode
		END AS MatchCode,
		CASE
			WHEN m.sporttype = 50 AND m.ChildMatchType = 200 THEN ISNULL(pm14.GlobalShowTime, pm.GlobalShowTime)
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
			AND m.sporttype = 50
			AND m.ChildMatchType = 200
		LEFT JOIN dbo.match AS pm WITH (NOLOCK)
			ON pm.matchid = m.ParentID
			AND m.sporttype = 50
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
			WHEN m.sporttype = 50 AND m.ChildMatchType = 200 THEN ISNULL(pmbk.matchid, ISNULL(pm14.matchid, pm.matchid))
			ELSE m.matchid
		END AS MatchId,
		CASE
			WHEN m.sporttype = 50 AND m.ChildMatchType = 200 THEN ISNULL(pmbk.matchcode, ISNULL(pm14.matchcode, pm.matchcode))
			ELSE m.matchcode
		END AS MatchCode,
		CASE
			WHEN m.sporttype = 50 AND m.ChildMatchType = 200 THEN ISNULL(pmbk.GlobalShowTime, ISNULL(pm14.GlobalShowTime, pm.GlobalShowTime))
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
			AND m.sporttype = 50
			AND m.ChildMatchType = 200
		LEFT JOIN dbo.match14 AS pm14 WITH (NOLOCK)
			ON pm14.matchid = m.ParentID
			AND m.sporttype = 50
			AND m.ChildMatchType = 200
		LEFT JOIN dbo.match AS pm WITH (NOLOCK)
			ON pm.matchid = m.ParentID
			AND m.sporttype = 50
			AND m.ChildMatchType = 200
		INNER JOIN @SportBettype AS sbt ON bm.bettype = sbt.Bettype
	WHERE bm.refno = @RefNo

	SELECT	@minMatchdate = MIN(matchdate),
			@maxMatchdate = MAX(matchdate)
	FROM @parlay_base

	-- Get bettrans and BetParlayResult data
	IF EXISTS (SELECT 1 FROM @parlay_base WHERE MatchDate < @BalanceUpDay)		-- bettrans_bk
	BEGIN
		INSERT INTO @tmpBettrans
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
			CASE
				WHEN b.statusid NOT IN (0,1) THEN b.winlost - b.actual_stake 
				ELSE b.winlost
			END AS winlost,
			b.playercomm,
			b.status,
			CASE WHEN b.comstatus = '1' THEN 1 ELSE 0 END AS comstatus,
			b.betteam,
			dp.ip,
			b.spositiontaking,
			b.mpositiontaking,
			b.apositiontaking,
			b.swinlost,
			b.mwinlost,
			b.awinlost,
			b.sdiscount,
			b.adiscount,
			b.discount,
			b.scomm - b.acomm,
			b.acomm - b.comm,
			b.comm - b.playercomm,
			b.hdp1,
			b.hdp2,
			ISNULL(b.betcheck, '') AS BetCheck,
			'' AS TransDesc,
			ISNULL(b.ExtraInfo, '') AS ExtraInfo,
			b.DeviceType,
			CASE
				WHEN b.betcheck IS NULL THEN LEN(b.betteam)		-- old Parlay tickets
				ELSE b.hdp2										-- new Parlay tickets
			END AS N,
			CASE
				WHEN b.betcheck IS NULL THEN CONVERT(INT, b.hdp2)	-- old Parlay tickets
				ELSE CONVERT(INT, b.betcheck)						-- new Parlay tickets
			END AS Bitmap
		FROM DBARC.bodb_archive.dbo.bettrans_bk AS b WITH (NOLOCK)
			CROSS APPLY dbo.f_IP_Decompress(b.Ip) AS dp
		WHERE b.custid = @CustId
			AND b.transid = @TransId
			AND b.bettype = 29

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
			b.serial,
			b.odds,
			b.modds,
			b.stake,
			b.winlost,
			b.statusid,
			b.ExtraValue
		FROM DBARC.bodb_Archive.dbo.betparlayresult AS b WITH (NOLOCK)
		WHERE b.refno = @RefNo
	END

	IF EXISTS (SELECT 1 FROM @parlay_base WHERE MatchDate BETWEEN @BalanceUpDay AND @MoveBetDay)		-- bettrans14
	BEGIN
		INSERT INTO @tmpBettrans
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
			CASE
				WHEN b.statusID NOT IN (0, 1) THEN b.winlost - b.actual_stake
				ELSE b.winlost
			END AS winlost,
			b.playercomm,
			b.status,
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
			b.adiscount,
			b.discount,
			b.scomm - b.acomm,
			b.acomm - b.comm,
			b.comm - b.playercomm,
			b.hdp1,
			b.hdp2,
			ISNULL(b.betcheck, '') AS BetCheck,
			'' AS TransDesc,
			ISNULL(b.ExtraInfo, '') AS ExtraInfo,
			b.DeviceType,
			CASE
				WHEN b.betcheck IS NULL THEN LEN(b.betteam)		-- old Parlay tickets
				ELSE b.hdp2										-- new Parlay tickets
			END AS N,
			CASE
				WHEN b.betcheck IS NULL THEN CONVERT(INT, b.hdp2)	-- old Parlay tickets
				ELSE CONVERT(INT, b.betcheck)						-- new Parlay tickets
			END AS Bitmap
		FROM dbo.bettrans14 AS b WITH (NOLOCK)
		WHERE b.custid = @CustId
			AND b.transid = @TransId
			AND b.bettype = 29
	END

	IF EXISTS (SELECT 1 FROM @parlay_base WHERE MatchDate > @MoveBetDay)		-- bettrans
	BEGIN
		INSERT INTO @tmpBettrans
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
			b.adiscount,
			b.discount,
			b.scomm - b.acomm,
			b.acomm - b.comm,
			b.comm - b.playercomm,
			b.hdp1,
			b.hdp2,
			ISNULL(b.betcheck, '') AS BetCheck,
			'' AS TransDesc,
			ISNULL(b.ExtraInfo, '') AS ExtraInfo,
			b.DeviceType,
			CASE
				WHEN b.betcheck IS NULL THEN LEN(betteam)	-- old Parlay tickets
				ELSE b.hdp2									-- new Parlay tickets
			END AS N,
			CASE
				WHEN b.betcheck IS NULL THEN CONVERT(INT, b.hdp2)	-- old Parlay tickets
				ELSE CONVERT(INT, b.betcheck)						-- new Parlay tickets
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

		;WITH sub AS (SELECT ROW_NUMBER() OVER (ORDER BY matchid) RN, matchid FROM @parlay_base)
		UPDATE pb
		SET RN = sub.RN
		FROM sub
			INNER JOIN @parlay_base AS pb ON sub.matchid = pb.matchid

		-- prepare N
		;WITH sub AS (SELECT COUNT(*) cnt FROM @parlay_base)
		UPDATE pb
		SET Cnt = sub.cnt,
			bCnt = t.N
		FROM sub,
			@parlay_base AS pb,
			@tmpBettrans AS t

		IF NOT EXISTS(SELECT 1 FROM @parlay_base WHERE cnt <> bCnt)
		BEGIN
			INSERT INTO @betParlayDetail
			SELECT
				pb.RefNo,
				rc.Serial,
				pb.MatchId
			FROM
				@parlay_base AS pb
				INNER JOIN @tmpBettrans AS tb ON pb.refno = tb.refno
				INNER JOIN dbo.RefCombinationSet AS rcs WITH (NOLOCK) ON pb.CNT = rcs.N AND (tb.Bitmap & rcs.bitmap) > 0
				INNER JOIN dbo.RefCombination AS rc WITH (NOLOCK) ON rcs.N = rc.N AND rcs.R = rc.R AND pb.RN = rc.seq

			;WITH ParlayStake AS (SELECT refno, RN, setstake FROM @parlay_base)
			INSERT INTO @betParlayResult
			SELECT DISTINCT 
				tb.RefNo,
				rc.Serial,
				tb.WinLostDate,
				ps.SetStake
			FROM
				@tmpBettrans AS tb
				INNER JOIN dbo.RefCombinationSet AS rcs WITH (NOLOCK) ON tb.N = rcs.N AND (tb.bitmap & rcs.bitmap) > 0
				INNER JOIN dbo.RefCombination AS rc WITH (NOLOCK) ON rcs.N = rc.N AND rcs.R = rc.R
				INNER JOIN ParlayStake AS ps ON ps.refno = tb.RefNo AND ps.RN = rc.R

			INSERT INTO @tmpResults
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
			
			INSERT INTO @tmpMatch
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
			SELECT ROW_NUMBER() OVER (ORDER BY matchid) RN, matchid FROM @parlay_base
		)
		UPDATE pb
		SET RN = sub.RN
		FROM sub
			INNER JOIN @parlay_base AS pb ON sub.matchid = pb.matchid

		-- Prepare N
		;WITH sub AS (SELECT COUNT(*) cnt FROM @parlay_base)
		UPDATE pb
		SET Cnt = sub.cnt,
			bCnt = t.N
		FROM sub,
			@parlay_base AS pb,
			@tmpBettrans AS t
		
		IF NOT EXISTS(SELECT 1 FROM @parlay_base WHERE cnt <> bCnt)
		BEGIN
			INSERT INTO @betParlayDetail
			SELECT 
				pb.RefNo,
				rc.Serial,
				pb.MatchId
			FROM
				@parlay_base AS pb
				INNER JOIN @tmpBettrans AS tb ON pb.refno = tb.refno
				INNER JOIN dbo.RefCombinationSet AS rcs WITH (NOLOCK) ON pb.CNT = rcs.N AND (tb.Bitmap & rcs.bitmap) > 0
				INNER JOIN dbo.RefCombination AS rc WITH (NOLOCK) ON rcs.N = rc.N AND rcs.R = rc.R AND pb.RN = rc.seq
		END

		-- Get homeid, awayid
		IF @MinMatchdate < @BalanceUpday
		BEGIN
			INSERT INTO @tmpMatch
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
			INSERT INTO @tmpMatch
			SELECT
				p.serial,
				m.homeid,
				m.awayid,
				m.IsNeutral
			FROM @tmpResults AS p
				INNER JOIN @betParlayDetail AS b ON p.Serial = b.Serial
				INNER JOIN dbo.match14 AS m WITH (NOLOCK) ON b.matchid = m.matchid
		END

		IF @MaxMatchdate > @MoveBetDay
		BEGIN
			INSERT INTO @tmpMatch
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

	DECLARE
		@WinLost	MONEY,
		@Discount	MONEY,
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
				b.TransDesc = CONVERT(VARCHAR(20), ISNULL(bpr.ExtraValue, ''))
			FROM @tmpBettrans AS b
				INNER JOIN dbo.BetParlayResult AS bpr WITH (NOLOCK) ON bpr.RefNo = b.RefNo
		END
		ELSE
		BEGIN
			UPDATE b
			SET
				b.Odds = bpr.Odds,
				b.Modds = bpr.mOdds,
				b.TransDesc = CONVERT(VARCHAR(20), ISNULL(bpr.ExtraValue, ''))
			FROM @tmpBettrans AS b
				INNER JOIN DBARC.bodb_Archive.dbo.BetParlayResult AS bpr WITH (NOLOCK) ON bpr.RefNo = b.RefNo
		END
	END

	SELECT DISTINCT
		CASE WHEN ISNULL(BetId, 0) = 0 THEN TransId ELSE BetId END AS TransId,
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
	FROM ( SELECT DISTINCT * FROM @tmpResults ) AS tmp
	ORDER BY CASE WHEN statusid NOT IN (0, 1) THEN winlostdate ELSE '' END ASC

	SELECT DISTINCT * FROM @tmpMatch
END
GO