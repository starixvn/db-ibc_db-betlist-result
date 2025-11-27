/*<info serverAlias="DBACC-bodb02" executers="wsv_nap,wsv_alp, wsv_alpv" viewers="" isFunction="0" isNested="0"></info>*/

ALTER PROCEDURE [dbo].[Acc_BetlistCombinationParlay_Details]
	@RefNo			BIGINT,
	@CustId			INT,
	@MoveBetDay		SMALLDATETIME,
	@BalanceUpDay	SMALLDATETIME,
	@Outstanding	MONEY		= 0 OUTPUT,
	@IsParlayBoost	BIT			= 0 OUTPUT
AS

/*
	Created by: 20110802@Johnson
	Task: Get details info for Combination Mix Parlay
	DB: DBACC.BODB02
	
	Revisions:
		- 20110808@Sophia: Add permission [bodbDownlineNet] for Agent site call this sp
		- 20110809@Sophia: Add Playercomm
		- 20110826@Jamie: Result Archive
		- 20111202@Johnson: Correct outstanding
		- 20120229@Lukas: Fix bug in case of sub & main ticket are not in the same table (bettrans14, bettrans_bk,..)
		- 20130121@Dan: change linked server DB06 to DBARC
		- 20130404@Daniel (on live version) : fix bug check movebet day in case movebetday = min(matchdate)
		- 20151210@Kos: Change odds, modds data type from SMALLMONEY to MONEY [Redmine: #48660]
		- 20160408@Kos: Support Combo Parlay [#Redmine: 55282]
		- 20161010@Kos: Add product bet type range for sub tickets [Redmine: #65045]
		- 20170210@Kos: Add DISTINCT to prevent duplicate ticket detail [Redmine: #71007]
		- 20170801@Kos: Return TransId instead of 0 [Redmine: #73545]
		- 20190912@Kos: Show LOSE combination details [Redmine: #117888]
					- Remove param @Language
					- Move from DBAGE.bodb02 to DBACC.bodb02
		- 20191104@Kos: Hotfix - Duplicate data in Balance Up time [Redmine: #123093]
		- 20191114@Kos: Show (N) for neutral match [Redmine: #123772]
		- 20201123@Kos: Support God Of Fortune [Redmine: #145834]
		- 20231004@Kos: Support Parlay Boost [Redmine: #194992]
					- Add output param @IsParlayBoost BIT
					- Return additional columns Odds MONEY, ExtraValue MONEY
					- Remove param @TransId, @BetId
		- 20251103@Virgil: Fix Sonarqube [Redmine: #242378]
		
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

	DECLARE @tmpBettrans AS TABLE (
		TransId			BIGINT,
		RefNo			BIGINT,
		OddsSpread		MONEY,
		BetTeam			NVARCHAR(10),
		Status			NVARCHAR(10),
		Stake			MONEY,
		Actual_Stake	MONEY,
		WinLost			MONEY,
		ExtraInfo		VARCHAR(1000),
		--for generating combination parlays if not in BetParlayResult
		N				TINYINT,	-- Number of selection
		Bitmap			INT,		-- Combination Bitmap
		WhTicket		TINYINT
	)

	DECLARE @parlay_base AS TABLE (
		TransId		BIGINT,
		RefNo		BIGINT,
		MatchId		INT,
		MatchDate	SMALLDATETIME,
		--for generating combination parlays
		RN			TINYINT,	-- set No. for selection in the combination
		Cnt			TINYINT,	-- total selection count, base on bettransm/14
		bCnt		TINYINT		-- total selection count, stored in bettrans
	)

	DECLARE @tmpResults TABLE (
		WinLostDate SMALLDATETIME,
		TransId		BIGINT,
		Serial		BIGINT,
		StatusId	TINYINT,
		Status		VARCHAR(20),
		Odds		MONEY,
		MOdds		MONEY,
		Stake		MONEY,
		WinLost		MONEY,
		PlayerComm	MONEY,
		ExtraValue	MONEY
	)

	DECLARE @betParlayDetail TABLE (
		RefNo	BIGINT,
		Serial	INT,
		MatchId	INT
	)
	DECLARE @tmpMatch AS TABLE (
		Serial		BIGINT,
		HomeId		INT,
		AwayId		INT,
		IsNeutral	BIT
	)

	DECLARE @minMatchdate SMALLDATETIME,
			@maxMatchdate SMALLDATETIME

	-- Get bettransm data
	INSERT INTO @parlay_base (
		TransId,
		RefNo,
		MatchId,
		MatchDate )
	SELECT
		bm.transid,
		bm.refno,
		m.matchid,
		bm.matchdate
	FROM dbo.bettransm AS bm WITH (NOLOCK)
		INNER JOIN dbo.match AS m WITH (NOLOCK) ON bm.matchid = m.matchid
		INNER JOIN @SportBettype AS sbt ON bm.bettype = sbt.Bettype
	WHERE bm.refno = @RefNo AND bm.custid = @CustId
	UNION
	SELECT
		bm.transid,
		bm.refno,
		m.matchid,
		bm.matchdate
	FROM dbo.bettransm14 AS bm WITH (NOLOCK)
		INNER JOIN dbo.match14 AS m WITH (NOLOCK) ON bm.matchid = m.matchid
		INNER JOIN @SportBettype AS sbt ON bm.bettype = sbt.Bettype
	WHERE bm.refno = @RefNo
	UNION
	SELECT
		bm.transid,
		bm.refno,
		m.matchid,
		bm.matchdate
	FROM bodb_Archive.dbo.bettransm AS bm WITH (NOLOCK)
		INNER JOIN bodb_Archive.dbo.match_bk AS m WITH (NOLOCK) ON bm.matchid = m.matchid
		INNER JOIN @SportBettype AS sbt ON bm.bettype = sbt.Bettype
	WHERE bm.refno = @RefNo

	SELECT	@minMatchdate = MIN(matchdate),
			@maxMatchdate = MAX(matchdate)
	FROM @parlay_base

	-- Get bettrans and BetParlayResult data
	IF @minMatchdate < @BalanceUpDay		-- bettrans_bk range
	BEGIN
		INSERT INTO @tmpBettrans (TransId, RefNo, OddsSpread, BetTeam, Status, Stake, Actual_Stake, WinLost, ExtraInfo, N, Bitmap, WhTicket)
		SELECT
			bk.transid,
			bk.refno,
			bk.oddsspread,
			bk.betteam,
			bk.status,
			bk.stake,
			bk.actual_stake,
			bk.winlost,
			ISNULL(bk.ExtraInfo, '') AS ExtraInfo,
			CASE
				WHEN bk.betcheck IS NULL THEN LEN(bk.betteam)				-- old Parlay tickets
				WHEN bk.bettype = 29 AND bk.oddsspread = 3 THEN bk.betid	-- Hybrid Parlay tickets
				ELSE bk.hdp2												-- new Parlay tickets
			END AS N,
			CASE
				WHEN bk.betcheck IS NULL THEN CONVERT(INT, bk.hdp2)	-- old Parlay tickets
				ELSE CONVERT(INT, bk.betteam)						-- new Parlay tickets
			END AS Bitmap,
			3 AS WhTicket
		FROM bodb_Archive.dbo.bettrans_bk AS bk WITH (NOLOCK)
		WHERE bk.custid = @CustId
			AND bk.refno = @RefNo
			AND bk.matchid = 29
			AND bk.bettype = 29

		INSERT INTO @tmpResults (
			WinLostDate,
			Serial,
			Odds,
			MOdds,
			Stake,
			WinLost,
			StatusId,
			PlayerComm,
			ExtraValue )
		SELECT
			winlostdate,
			Serial,
			odds,
			mOdds,
			stake,
			winlost,
			statusid,
			playercomm,
			ExtraValue
		FROM bodb_Archive.dbo.BetParlayResult WITH (NOLOCK)
		WHERE RefNo = @RefNo
	END

	IF @minMatchdate <= @MoveBetDay		--- bettrans14 range
	BEGIN
		INSERT INTO @tmpBettrans (TransId, RefNo, OddsSpread, BetTeam, Status, Stake, Actual_Stake, WinLost, ExtraInfo, N, Bitmap, WhTicket)
		SELECT
			b14.transid,
			b14.refno,
			b14.oddsspread,
			b14.betteam,
			b14.status,
			b14.stake,
			b14.actual_stake,
			b14.winlost,
			ISNULL(b14.ExtraInfo, '') AS ExtraInfo,
			CASE
				WHEN b14.betcheck IS NULL THEN LEN(b14.betteam)				-- old Parlay tickets
				WHEN b14.bettype = 29 AND b14.oddsspread = 3 THEN b14.betid	-- Hybrid Parlay tickets
				ELSE b14.hdp2												-- new Parlay tickets
			END AS N,
			CASE
				WHEN b14.betcheck IS NULL THEN CONVERT(INT, b14.hdp2)	-- old Parlay tickets
				ELSE CONVERT(INT, b14.betteam)							-- new Parlay tickets
			END AS Bitmap,
			2 AS WhTicket
		FROM dbo.bettrans14 AS b14 WITH (NOLOCK)
		WHERE b14.custid = @CustId
			AND b14.refno = @RefNo
			AND b14.matchid = 29
			AND b14.bettype = 29
			AND b14.transid NOT IN (SELECT TransId FROM @tmpBettrans)
	END

	IF @maxMatchdate > @MoveBetDay  --- get data from bettrans
	BEGIN
		INSERT INTO @tmpBettrans (TransId, RefNo, OddsSpread, BetTeam, Status, Stake, Actual_Stake, WinLost, ExtraInfo, N, Bitmap, WhTicket)
		SELECT
			transid,
			refno,
			oddsspread,
			betteam,
			status,
			stake,
			actual_stake,
			winlost,
			ISNULL(ExtraInfo, '') AS ExtraInfo,
			CASE
				WHEN betcheck IS NULL THEN LEN(betteam)			-- old Parlay tickets
				WHEN bettype = 29 AND oddsspread = 3 THEN betid	-- Hybrid Parlay tickets
				ELSE hdp2										-- new Parlay tickets
			END AS N,
			CASE
				WHEN betcheck IS NULL THEN CONVERT(INT, hdp2)	-- old Parlay tickets
				ELSE CONVERT(INT, betteam)						-- new Parlay tickets
			END AS Bitmap,
			1 AS WhTicket
		FROM dbo.bettrans WITH (NOLOCK)
		WHERE custid = @CustId
			AND refno = @RefNo
			AND matchid = 29
			AND bettype = 29
			AND transid NOT IN (SELECT TransId FROM @tmpBettrans)
	END
	
	INSERT INTO @tmpResults (
		WinLostDate,
		Serial,
		Odds,
		MOdds,
		Stake,
		WinLost,
		StatusId,
		PlayerComm, 
		ExtraValue )
	SELECT
		winlostdate,
		Serial,
		Odds,
		mOdds,
		stake,
		winlost,
		statusid,
		playercomm,
		extravalue
	FROM dbo.BetParlayResult WITH(NOLOCK)
	WHERE RefNo = @RefNo
		AND Serial NOT IN (SELECT Serial FROM @tmpResults)

	-- Generate betParlayDetail
	IF @minMatchdate < @BalanceUpday
	BEGIN
		;WITH sub AS 
		(
			SELECT ROW_NUMBER() OVER (ORDER BY matchid ASC) RN, matchid FROM @parlay_base
		)
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
			INSERT INTO @betParlayDetail (RefNo, Serial, MatchId )
			SELECT
				pb.RefNo,
				rc.Serial,
				pb.MatchId
			FROM
				@parlay_base AS pb
				INNER JOIN @tmpBettrans AS tb ON pb.RefNo = tb.RefNo
				INNER JOIN dbo.RefCombinationSet AS rcs WITH (NOLOCK) ON pb.CNT = rcs.N AND (tb.Bitmap & rcs.bitmapR) > 0
				INNER JOIN dbo.RefCombination AS rc WITH (NOLOCK) ON rcs.N = rc.N AND rcs.R = rc.R AND pb.RN = rc.seq
		END
	END
	ELSE
	BEGIN
		INSERT INTO @betParlayDetail (RefNo, Serial, MatchId )
		SELECT
			refno,
			serial,
			matchid
		FROM dbo.BetParlayDetail WITH (NOLOCK)
		WHERE refno = @RefNo
	END

	-- Get homeid, awayid
	IF @MinMatchdate < @BalanceUpday
	BEGIN
		INSERT INTO @tmpMatch (Serial, HomeId, AwayId, IsNeutral)
		SELECT
			p1.serial,
			m1.homeid,
			m1.awayid,
			m1.IsNeutral
		FROM @tmpResults AS p1
			INNER JOIN @betParlayDetail AS b1 ON p1.Serial = b1.Serial
			INNER JOIN bodb_Archive.dbo.match_bk AS m1 WITH (NOLOCK) ON b1.MatchId = m1.matchid
		WHERE p1.StatusId NOT IN (0, 1)
	END

	IF @MinMatchdate <= @MoveBetDay
	BEGIN
		INSERT INTO @tmpMatch (Serial, HomeId, AwayId, IsNeutral)
		SELECT
			p2.serial,
			m2.homeid,
			m2.awayid,
			m2.IsNeutral
		FROM @tmpResults AS p2
			INNER JOIN @betParlayDetail AS b2 ON p2.Serial = b2.Serial
			INNER JOIN dbo.match14 AS m2 WITH (NOLOCK) ON b2.MatchId = m2.matchid
		WHERE p2.StatusId NOT IN (0, 1)
	END

	IF @MaxMatchdate > @MoveBetDay
	BEGIN
		INSERT INTO @tmpMatch (Serial, HomeId, AwayId, IsNeutral)
		SELECT
			p3.serial,
			m3.homeid,
			m3.awayid,
			m3.IsNeutral
		FROM @tmpResults AS p3
			INNER JOIN @betParlayDetail AS b3 ON p3.Serial = b3.Serial
			INNER JOIN dbo.match AS m3 WITH (NOLOCK) ON b3.MatchId = m3.matchid
		WHERE p3.StatusId NOT IN (0, 1)
	END
	
	-- Calculate outstanding
	SELECT @Outstanding = MAX(stake)
	FROM @tmpBettrans

	SELECT @Outstanding = @Outstanding - ISNULL(SUM(stake), 0)
	FROM @tmpResults
	WHERE StatusId NOT IN (0, 1)

	DECLARE
		@Actual_Stake	MONEY,
		@WinLost		MONEY,
		@Discount		MONEY,
		@OriginalOdds	MONEY,
		@BetTeam		NVARCHAR(10),
		@Status			NVARCHAR(10),
		@ExtraInfo		VARCHAR(1000);

	SELECT
		@Actual_Stake = Actual_Stake,
		@WinLost = WinLost,
		@Discount = CASE
						WHEN ExtraInfo LIKE '%p1%' THEN
							ISNULL(CAST(('<xml>' + ExtraInfo + '</xml>') AS XML).value('data(/xml/p1/@d)[1]','MONEY'), 0)
						ELSE 0
					END,
		@BetTeam = BetTeam,
		@Status = Status,
		@IsParlayBoost = CASE
							WHEN BetTeam = '1'
								AND OddsSpread = 2
								AND Status = 'Won'
								AND ISNULL(CAST(('<xml>' + ExtraInfo + '</xml>') AS XML).value('data(/xml/p1/@bba)[1]','MONEY'), 0) > 0 THEN 1
							ELSE 0
						END,
		@ExtraInfo = IIF(OddsSpread = 3, ExtraInfo, NULL)
	FROM @tmpBettrans

	-- Get original odds for Mix Parlay
	IF @BetTeam = '1'
	BEGIN
		IF @Status IN ('Running', 'Waiting')
		BEGIN
			IF EXISTS (SELECT 1 FROM dbo.BetParlayDetail WHERE RefNo = @RefNo)
			BEGIN
				SELECT @OriginalOdds = dbo.PRODUCT(odds)
				FROM dbo.BetParlayDetail WITH (NOLOCK)
				WHERE RefNo = @RefNo
				GROUP BY RefNo
			END
			ELSE
			BEGIN
				SELECT @OriginalOdds = dbo.PRODUCT(odds)
				FROM dbo.bettransm WITH (NOLOCK)
				WHERE RefNo = @RefNo
				GROUP BY RefNo
			END
		END
	END

	-- Return combo detail
	SELECT DISTINCT
		WinLostDate,
		TransId,
		Serial,
		StatusId,
		CASE StatusId
			WHEN 101 THEN 'REJECT'
			WHEN 102 THEN 'VOID'
			WHEN 103 THEN 'REFUND'
			WHEN 111 THEN 'DRAW'
			WHEN 112 THEN 'WON'
			WHEN 113 THEN 'LOSE'
			ELSE '' 
		END AS status,
		CASE
			WHEN @Status IN ('Running', 'Waiting') THEN @OriginalOdds
			ELSE Odds
		END AS Odds,
		CASE
			WHEN @BetTeam = '1' AND StatusId = 113 AND MOdds = 0 THEN Odds
			ELSE MOdds
		END AS Modds,
		Stake,
		CASE
			WHEN @Discount > 0 THEN @WinLost - @Actual_Stake
			ELSE WinLost - Stake
		END AS WinLost,
		PlayerComm,
		ExtraValue,
		@ExtraInfo AS ExtraInfo
	FROM @tmpResults
	WHERE StatusId NOT IN (0, 1)
	ORDER BY WinLostDate ASC

	SELECT DISTINCT 
		Serial,
		HomeId,
		AwayId,
		IsNeutral
	FROM @tmpMatch
END
GO
