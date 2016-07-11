ALTER PROCEDURE [dbo].[Acc_BetlistCombinationParlay_ByTransID]
	@TransId		BIGINT,
	@CustId			INT,
	@MoveBetDay		DATETIME,
	@BalanceUpDay	DATETIME
AS

/*
	Created: 20111128@Johnson
	Task: Get details of parlay tickets
	DB: DBAGE.BODB02
	
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

	Paramters Explanation:
*/

BEGIN
	SET NOCOUNT ON

	DECLARE @RefNo		BIGINT,
		@CurrencyName	NVARCHAR(50),
		@minMatchdate	DATETIME,
		@maxMatchdate	DATETIME

	-- Check if @transid in bettrans
	SELECT @RefNo = b.refno,
		@CurrencyName = ex.currency
	FROM dbo.bettrans AS b WITH (NOLOCK)
		INNER JOIN dbo.Exchange AS ex WITH (NOLOCK) ON b.currency = ex.exchangeid
	WHERE transid = @TransId
		AND custid = @CustId
		AND bettype = 29

	IF @RefNo IS NULL
	BEGIN
		SELECT @RefNo = b.refno,
			@CurrencyName = ex.currency
		FROM dbo.bettrans14 AS b WITH (NOLOCK)
			INNER JOIN dbo.Exchange AS ex WITH (NOLOCK) ON b.currency = ex.exchangeid
		WHERE transid = @TransId
			AND custid = @CustId
			AND bettype = 29
	END

	IF @RefNo IS NULL
	BEGIN
		SELECT @RefNo = refno,
			@CurrencyName = ex.currency
		FROM DBARC.bodb_Archive.dbo.bettrans_bk AS b WITH (NOLOCK)
			INNER JOIN dbo.Exchange AS ex WITH (NOLOCK) ON b.currency = ex.exchangeid
		WHERE transid = @TransId
			AND custid = @CustId
			AND bettype = 29
	END

	DECLARE @tmpBettrans AS TABLE(
		TransId			BIGINT,
		BetId			BIGINT,
		TransDate		DATETIME,
		RefNo			BIGINT,
		WinLostDate		SMALLDATETIME,
		Odds			MONEY,
		Modds			MONEY,
		Stake			MONEY,
		Actual_Stake	MONEY,
		WinLost			MONEY,
		PlayerComm		MONEY,
		Status			VARCHAR(20),
		ComStatus		NVARCHAR(20),
		BetTeam			VARCHAR(20),
		Ip				VARCHAR(40),
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
		--for generating combination parlays if not in BetParlayResult
		N				TINYINT,		-- Number of selection
		Bitmap			INT				-- Combination bitmap
	)

	DECLARE @parlay_base AS TABLE (
		TransId			BIGINT,
		RefNo			BIGINT,
		WinLostDate		SMALLDATETIME,
		BetType			INT,
		HomeId			INT,
		AwayId			INT,
		Hdp1			SMALLMONEY,
		Hdp2			SMALLMONEY,
		Odds			MONEY,
		BetTeam			VARCHAR(20),
		StatusId		INT,
		LiveHomeScore	INT,
		LiveAwayScore	INT,
		LiveIndicator	BIT,
		LeagueId		INT,
		SportType		INT,
		IsNeutral		BIT,
		MatchId			INT,
		MatchCode		VARCHAR(50),
		MatchDate		DATETIME,
		BetCheck		NVARCHAR(50),
		TransDesc		NVARCHAR(200),
		SetStake		MONEY,
		--for generating combination parlays
		RN				TINYINT,	-- set No. for selection in the combination
		Cnt				TINYINT,	-- total selection count, base on bettransm/14
		bCnt			TINYINT		-- total selection count, stored in bettrans
	)

	DECLARE @tmpResults AS TABLE(
		WinLostDate	DATETIME,
		Serial		BIGINT,
		Modds		MONEY,
		Stake		MONEY,
		WinLost		MONEY,
		StatusId	INT,
		Status		VARCHAR(20)
	)

	DECLARE @betParlayDetail TABLE (
		RefNo	BIGINT,
		Serial	INT,
		MatchId	INT
	)

	DECLARE @tmpMatch AS TABLE(
		Serial	BIGINT,
		HomeId	INT,
		AwayId	INT
	)

	-- Get bettransm data
	INSERT INTO @parlay_base (
		TransId,
		RefNo,
		WinLostDate,
		BetType,
		HomeId,
		AwayId,
		Hdp1,
		Hdp2,
		Odds,
		BetTeam,
		StatusId,
		LiveHomeScore,
		LiveAwayScore,
		LiveIndicator,
		LeagueId,
		SportType,
		IsNeutral,
		MatchId,
		MatchCode,
		MatchDate,
		BetCheck,
		TransDesc,
		SetStake)
	SELECT
		bm.transid,
		bm.refno,
		bm.winlostdate,
		bm.bettype,
		m.homeid,
		m.awayid,
		bm.hdp1,
		bm.hdp2,
		bm.odds,
		bm.betteam,
		bm.statusid,
		bm.livehomescore,
		bm.liveawayscore,
		bm.liveindicator,
		m.leagueid,
		m.sporttype,
		m.isNeutral,
		m.matchid,
		m.matchcode,
		bm.matchdate,
		ISNULL(bm.betcheck, '') AS BetCheck,
		ISNULL(bm.transdesc, '') AS TransDesc,
		bm.stake
	FROM dbo.bettransm AS bm WITH (NOLOCK)
		INNER JOIN dbo.match AS m WITH (NOLOCK) ON bm.matchid = m.matchid
	WHERE refno = @RefNo AND custid = @custid

	UNION

	SELECT
		bm.transid,
		bm.refno,
		bm.winlostdate,
		bm.bettype,
		m.homeid,
		m.awayid,
		bm.hdp1,
		bm.hdp2,
		bm.odds,
		bm.betteam,
		bm.statusid,
		bm.livehomescore,
		bm.liveawayscore,
		bm.liveindicator,
		m.leagueid,
		m.sporttype,
		m.isNeutral,
		m.matchid,
		m.matchcode,
		bm.matchdate,
		ISNULL(bm.betcheck, '') AS BetCheck,
		ISNULL(bm.transdesc, '') AS TransDesc,
		bm.stake
	FROM dbo.bettransm14 AS bm WITH (NOLOCK)
		INNER JOIN dbo.match14 AS m WITH (NOLOCK) ON bm.matchid = m.matchid
	WHERE refno = @RefNo

	UNION

	SELECT
		bm.transid,
		bm.refno,
		bm.winlostdate,
		bm.bettype,
		m.homeid,
		m.awayid,
		bm.hdp1,
		bm.hdp2,
		bm.odds,
		bm.betteam,
		bm.statusid,
		bm.livehomescore,
		bm.liveawayscore,
		bm.liveindicator,
		m.leagueid,
		m.sporttype,
		m.isNeutral,
		m.matchid,
		m.matchcode,
		bm.matchdate,
		ISNULL(bm.betcheck, '') AS BetCheck,
		ISNULL(bm.transdesc, '') AS TransDesc,
		bm.stake
	FROM DBARC.bodb_archive.dbo.bettransm AS bm WITH (NOLOCK)
		INNER JOIN DBARC.bodb_archive.dbo.match_bk AS m WITH (NOLOCK) ON bm.matchid = m.matchid
	WHERE refno = @RefNo

	SELECT	@minMatchdate = MIN(matchdate),
			@maxMatchdate = MAX(matchdate)
	FROM @parlay_base

	-- Get bettrans and BetParlayResult data
	IF @minMatchDate < @BalanceUpDay	-- get data from bettrans_bk
	BEGIN
		INSERT INTO @tmpBettrans
		SELECT
			transid,
			betid,
			transdate,
			refno,
			winlostdate,
			odds,
			modds,
			stake,
			actual_stake,
			CASE
				WHEN statusid NOT IN (0,1) THEN winlost - actual_stake 
				ELSE winlost
			END AS winlost,
			playercomm,
			status,
			CASE WHEN b.comstatus = '1' THEN 1 ELSE 0 END AS comstatus,
			betteam,
			ip,
			spositiontaking,
			mpositiontaking,
			apositiontaking,
			swinlost,
			mwinlost,
			awinlost,
			sdiscount,
			adiscount,
			discount,
			scomm - acomm,
			acomm - comm,
			comm - playercomm,
			hdp1,
			hdp2,
			ISNULL(b.betcheck, '') AS BetCheck,
			CASE
				WHEN betcheck IS NULL THEN LEN(betteam)		-- old Parlay tickets
				ELSE hdp2									-- new Parlay tickets
			END AS N,
			CASE
				WHEN betcheck IS NULL THEN CONVERT(INT, hdp2)	-- old Parlay tickets
				ELSE CONVERT(INT, betcheck)						-- new Parlay tickets
			END AS Bitmap
		FROM DBARC.bodb_archive.dbo.bettrans_bk AS b WITH(NOLOCK) 
		WHERE custid = @custid
			AND refno = @RefNo
			AND matchid = 29
			AND bettype = 29
			AND transid NOT IN (SELECT transid FROM @tmpBettrans)

		INSERT INTO @tmpResults (
			WinLostDate,
			Serial,
			Modds,
			Stake,
			WinLost,
			StatusId)
		SELECT 
			winlostdate,
			serial,
			modds,
			stake,
			winlost,
			statusid
		FROM DBARC.bodb_Archive.dbo.betparlayresult AS b WITH (NOLOCK)
		WHERE refno = @RefNo
	END

	IF @minMatchdate <= @MoveBetDay		-- get data from bettrans14
	BEGIN
		INSERT INTO @tmpBettrans
		SELECT
			transid,
			betid,
			transdate,
			refno,
			winlostdate,
			odds,
			modds,
			stake,
			actual_stake,
			CASE
				WHEN statusid NOT IN (0, 1) THEN winlost - actual_stake
				ELSE winlost
			END AS winlost,
			playercomm,
			status,
			CASE WHEN b.comstatus = '1' THEN 1 ELSE 0 END AS comstatus,
			betteam,
			ip,
			spositiontaking,
			mpositiontaking,
			apositiontaking,
			swinlost,
			mwinlost,
			awinlost,
			sdiscount,
			adiscount,
			discount,
			scomm - acomm,
			acomm - comm,
			comm - playercomm,
			hdp1,
			hdp2,
			ISNULL(b.betcheck, '') AS BetCheck,
			CASE
				WHEN betcheck IS NULL THEN LEN(betteam)		-- old Parlay tickets
				ELSE hdp2									-- new Parlay tickets
			END AS N,
			CASE
				WHEN betcheck IS NULL THEN CONVERT(INT, hdp2)	-- old Parlay tickets
				ELSE CONVERT(INT, betcheck)						-- new Parlay tickets
			END AS Bitmap
		FROM dbo.bettrans14 AS b WITH (NOLOCK)
		WHERE custid = @custid
			AND refno = @RefNo
			AND matchid = 29
			AND bettype = 29
			AND transid NOT IN (SELECT transid FROM @tmpBettrans)
	END

	IF @maxMatchdate > @MoveBetDay  --- get data from bettrans
	BEGIN
		INSERT INTO @tmpBettrans
		SELECT
			transid,
			betid,
			transdate,
			refno,
			winlostdate,
			odds,
			modds,
			stake,
			actual_stake,
			winlost - actual_stake AS winlost,
			playercomm,
			status,
			CASE WHEN b.comstatus = '1' THEN 1 ELSE 0 END AS comstatus,
			betteam,
			ip,
			spositiontaking,
			mpositiontaking,
			apositiontaking,
			swinlost,
			mwinlost,
			awinlost,
			sdiscount,
			adiscount,
			discount,
			scomm - acomm,
			acomm - comm,
			comm - playercomm,
			hdp1,
			hdp2,
			ISNULL(b.betcheck, '') AS BetCheck,
			CASE
				WHEN betcheck IS NULL THEN LEN(betteam)		-- old Parlay tickets
				ELSE hdp2									-- new Parlay tickets
			END AS N,
			CASE
				WHEN betcheck IS NULL THEN CONVERT(INT, hdp2)	-- old Parlay tickets
				ELSE CONVERT(INT, betcheck)						-- new Parlay tickets
			END AS Bitmap
		FROM dbo.bettrans AS b WITH (NOLOCK)
		WHERE custid = @custid
			AND refno = @RefNo
			AND matchid = 29
			AND bettype = 29
			AND transid NOT IN (SELECT transid FROM @tmpBettrans)
	END
	
	INSERT INTO @tmpResults (
		WinLostDate,
		Serial,
		Modds,
		Stake,
		WinLost,
		StatusId)
	SELECT 
		winlostdate,
		serial,
		modds,
		stake,
		winlost,
		statusid
	FROM dbo.betparlayresult AS b WITH (NOLOCK) 
	WHERE refno = @RefNo AND serial NOT IN (SELECT serial FROM @tmpResults)

	IF NOT EXISTS (SELECT TOP 1 1 FROM @tmpResults)
	BEGIN
		DECLARE @betParlayResult TABLE  (
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
				0 AS Modds,
				Stake,
				0 AS WinLost,
				0 AS StatusId,
				'running' AS Status
			FROM @betParlayResult
			
			INSERT INTO @tmpMatch
			SELECT
				p.serial,
				m.homeid,
				m.awayid
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
				m.awayid
			FROM @tmpResults AS p
				INNER JOIN @betParlayDetail AS b ON p.Serial = b.Serial
				INNER JOIN DBARC.bodb_Archive.dbo.match_bk AS m WITH (NOLOCK) ON b.matchid = m.matchid
		END

		IF @MinMatchdate <= @MoveBetDay
		BEGIN
			INSERT INTO @tmpMatch
			SELECT
				p.serial,
				homeid,
				awayid
			FROM @tmpResults AS p
				INNER JOIN @betParlayDetail AS b ON p.Serial = b.Serial
				INNER JOIN dbo.match14 AS m WITH (NOLOCK) ON b.matchid = m.matchid
		END

		IF @MaxMatchdate > @MoveBetDay
		BEGIN
			INSERT INTO @tmpMatch
			SELECT
				p.serial,
				homeid,
				awayid
			FROM @tmpResults AS p
				INNER JOIN @betParlayDetail AS b ON p.Serial = b.Serial
				INNER JOIN dbo.match AS m WITH (NOLOCK) ON b.matchid = m.matchid
		END
	END

	SELECT
		CASE WHEN ISNULL(BetId, 0) = 0 THEN TransId ELSE BetId END AS TransId,
		TransDate,
		RefNo,
		WinLostDate,
		Odds,
		Modds,
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
		BetCheck
	FROM @tmpBettrans

	SELECT
		TransId,
		RefNo,
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
		StatusId,
		LiveHomeScore,
		LiveAwayScore,
		LiveIndicator,
		LeagueId,
		SportType,
		IsNeutral,
		MatchId,
		MatchCode,
		BetCheck,
		TransDesc
	FROM @Parlay_Base

	SELECT
		WinLostDate,
		Serial,
		Modds,
		Stake,
		StatusId,
		CASE
			WHEN StatusId NOT IN (0, 1) THEN WinLost - Stake
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
		END AS status
	FROM @tmpResults
	ORDER BY CASE WHEN statusid NOT IN (0, 1) THEN winlostdate ELSE '' END ASC

	SELECT * FROM @tmpMatch
END



GO
GRANT VIEW DEFINITION ON [dbo].[Acc_BetlistCombinationParlay_ByTransID] TO [vnteam]
GO
GRANT EXECUTE ON [dbo].[Acc_BetlistCombinationParlay_ByTransID] TO [bodbAdminNet]