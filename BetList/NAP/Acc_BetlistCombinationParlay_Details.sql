USE [bodb02]
GO

/****** Object:  StoredProcedure [dbo].[Acc_BetlistCombinationParlay_Details]    Script Date: 4/8/2013 1:26:41 PM ******/
SET ANSI_NULLS ON
GO

SET QUOTED_IDENTIFIER ON
GO

ALTER PROCEDURE [dbo].[Acc_BetlistCombinationParlay_Details]
	@refno			BIGINT, 
	@transid		BIGINT		= 0,
	@betid			BIGINT		= 0,
	@custid			INT,
	@MoveBetDay		DATETIME,
	@BalanceUpDay	DATETIME,
	@Language		NVARCHAR(2)	= 'E',
	@Outstanding	MONEY		= 0 OUTPUT
AS

/*
	Created by: Johnson
	Date: 2011-08-02
	Task: Get details info for Combination Mix Parlay
	DB: DBAGE/BODB02
	Original: 
	
	Revisions: 
		- 20110808@Sophia: Add permission [bodbDownlineNet] for Agent site call this sp
		- 20110809@Sophia: Add Playercomm
		- 20110826@Jamie: Result Archive
		- 20111202@Johnson: Correct outstanding
		- 20120229@Lukas: Fix bug in case of sub & main ticket are not in the same table (bettrans14, bettrans_bk,..)
		- 20130121@Dan: change linked server DB06 to DBARC
		- 20130404@Daniel (on live version) : fix bug check movebet day in case movebetday = min(matchdate)
		- 20151210@Kos: Change odds, modds data type from SMALLMONEY to MONEY [Redmine: #48660]
*/

BEGIN
	SET NOCOUNT ON 

	DECLARE @tmpBettrans AS TABLE(
		transid			BIGINT,
		transdate		DATETIME,
		refno			BIGINT, 
		winlostdate		SMALLDATETIME,
		odds			MONEY,
		stake			MONEY, 
		actual_stake	MONEY, 
		winlost			MONEY, 
		playercomm		MONEY,
		status			VARCHAR(20),
		betteam			VARCHAR(20), 
		IP				VARCHAR(40), 
		spositiontaking	SMALLMONEY, 
		mpositiontaking	SMALLMONEY, 
		apositiontaking	SMALLMONEY, 
		swinlost		MONEY, 
		mwinlost		MONEY, 
		awinlost		MONEY, 
		sdiscount		SMALLMONEY, 
		adiscount		SMALLMONEY, 
		discount		SMALLMONEY, 
		scomm			MONEY, 
		acomm			MONEY, 
		comm			MONEY,
		--for generating combination parlays if not in BetParlayResult
		[N] [tinyint] , -- total selection (match)
		[cnt] [smallint] , -- total sub-ticket count
		[bitmap] [smallint] -- bitmap to identify which parlay set is choosen			
	)

	DECLARE @parlay_base AS TABLE(
		transid			BIGINT,
		refno			BIGINT,
		winlostdate		SMALLDATETIME,
		bettype			INT,
		homeid			INT,
		awayid			INT,
		hdp1			SMALLMONEY,
		hdp2			SMALLMONEY,
		odds			MONEY,
		betteam			VARCHAR(20),
		statusid		INT,
		livehomescore	INT,
		liveawayscore	INT,
		liveindicator	BIT,
		leagueid		INT,
		sporttype		INT,
		isNeutral		BIT,
		matchid			INT,
		matchcode		VARCHAR(50),
		matchdate		DATETIME,
		--for generating combination parlays
		RN TINYINT, -- set No. for selection in the combination
		CNT TINYINT, -- total selection count, base on bettransm/14
		bCNT TINYINT -- total selection count, stored in bettrans
	)

	DECLARE @tmpResults TABLE (
		winlostdate DATETIME,
		transid		BIGINT,
		serial		BIGINT,
		statusid	INT,
		status		VARCHAR(20),	
		modds		MONEY,
		stake		MONEY,
		winlost		MONEY,
		playercomm	MONEY
	)

	DECLARE @betParlayDetail TABLE (
		RefNo	BIGINT, 
		Serial	INT,
		matchid	INT
	)
	DECLARE @tmpMatch AS TABLE(
		serial	BIGINT,
		homeid	INT,
		awayid	INT
	)

	DECLARE @minMatchdate DATETIME,
			@maxMatchdate DATETIME

	
	INSERT INTO @parlay_base(transid,refno,winlostdate,bettype,homeid,awayid,hdp1,hdp2,odds,betteam,statusid,
						livehomescore,liveawayscore,liveindicator,leagueid,sporttype,isNeutral,matchid,matchcode,matchdate)

	SELECT	bm.transid, bm.refno, bm.winlostdate,bm.bettype,m.homeid, m.awayid, bm.hdp1, bm.hdp2, bm.odds, bm.betteam,
			bm.statusid, bm.livehomescore, bm.liveawayscore, bm.liveindicator, m.leagueid, m.sporttype, m.isNeutral ,m.matchid,	m.matchcode, bm.matchdate
	FROM dbo.bettransm AS bm WITH (NOLOCK)
		INNER JOIN dbo.match AS m WITH (NOLOCK) ON bm.matchid = m.matchid
	WHERE refno = @refno AND custid = @custid

	UNION

	SELECT	bm.transid, bm.refno, bm.winlostdate,bm.bettype,m.homeid, m.awayid, bm.hdp1, bm.hdp2, bm.odds, bm.betteam,
			bm.statusid, bm.livehomescore, bm.liveawayscore, bm.liveindicator, m.leagueid, m.sporttype, m.isNeutral ,m.matchid,	m.matchcode, bm.matchdate
	FROM dbo.bettransm14 AS bm WITH (NOLOCK)
		INNER JOIN dbo.match14 AS m WITH (NOLOCK) ON bm.matchid = m.matchid
	WHERE refno = @refno
	
	UNION 
	
	SELECT	bm.transid, bm.refno, bm.winlostdate,bm.bettype,m.homeid, m.awayid, bm.hdp1, bm.hdp2, bm.odds, bm.betteam,
			bm.statusid, bm.livehomescore, bm.liveawayscore, bm.liveindicator, m.leagueid, m.sporttype, m.isNeutral ,m.matchid,	m.matchcode, bm.matchdate
	FROM DBARC.bodb_archive.dbo.bettransm AS bm WITH (NOLOCK)
		INNER JOIN DBARC.bodb_archive.dbo.match_bk AS m WITH (NOLOCK) ON bm.matchid = m.matchid
	WHERE refno = @refno

	SELECT	@minMatchdate = MIN(matchdate),
			@maxMatchdate = MAX(matchdate)
	FROM @parlay_base


	IF @minMatchdate < @BalanceUpDay
	BEGIN
		INSERT INTO @tmpBettrans (transid, transdate, refno, winlostdate, odds, stake, actual_stake, winlost, playercomm, status, betteam, ip, spositiontaking,
			mpositiontaking, apositiontaking, swinlost,	mwinlost, awinlost,	sdiscount, adiscount, discount, scomm, acomm, comm, N, cnt, bitmap)
		SELECT
			transid,
			transdate,
			refno,
			winlostdate,
			modds AS odds,
			stake,
			actual_stake,
			CASE WHEN statusid NOT IN (0,1) THEN winlost - actual_stake ELSE winlost END AS winlost,		
			playercomm,
			status,
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
			len(betteam) AS N,
			hdp1 AS cnt,
			hdp2 AS bitmap
		FROM DBARC.bodb_archive.dbo.bettrans_bk AS b WITH(NOLOCK) 
		WHERE custid = @custid 
			AND refno = @refno 
			AND matchid = 29 
			AND bettype = 29
			AND transid NOT IN (SELECT transid FROM @tmpBettrans)

		INSERT INTO @tmpResults(winlostdate, serial, modds, stake, winlost, statusid, playercomm)
		SELECT winlostdate, serial, modds, stake, winlost, statusid, playercomm
		FROM DBARC.bodb_archive.dbo.betparlayresult b WITH (NOLOCK) 
		WHERE refno = @refno
	END

	IF @minMatchdate <= @MoveBetDay  --- get data from bettrans14
	BEGIN	
		INSERT INTO @tmpBettrans (transid, transdate, refno, winlostdate, odds, stake, actual_stake, winlost, playercomm, status, betteam, ip, spositiontaking,
			mpositiontaking, apositiontaking, swinlost,	mwinlost, awinlost,	sdiscount, adiscount, discount, scomm, acomm, comm, N, cnt, bitmap)
		SELECT
			transid,
			transdate,
			refno,
			winlostdate,
			modds AS odds,
			stake,
			actual_stake,
			CASE WHEN statusid NOT IN (0,1) THEN winlost - actual_stake ELSE winlost END AS winlost,		
			playercomm,
			status,
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
			len(betteam) AS N,
			hdp1 AS cnt,
			hdp2 AS bitmap
		FROM dbo.bettrans14 AS b WITH(NOLOCK) 
		WHERE custid = @custid 
			AND refno = @refno 
			AND matchid = 29 
			AND bettype = 29
			AND transid NOT IN (SELECT transid FROM @tmpBettrans)
	END

	IF @maxMatchdate > @MoveBetDay  --- get data from bettrans
	BEGIN		
		INSERT INTO @tmpBettrans (transid, transdate, refno, winlostdate, odds, stake, actual_stake, winlost, playercomm, status, betteam, ip, spositiontaking,
			mpositiontaking, apositiontaking, swinlost,	mwinlost, awinlost,	sdiscount, adiscount, discount, scomm, acomm, comm, N, cnt, bitmap)
		SELECT
			transid,
			transdate,
			refno,
			winlostdate,
			modds AS odds,
			stake,
			actual_stake,
			winlost - actual_stake AS winlost,		
			playercomm,
			status,
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
			len(betteam) AS N,
			hdp1 AS cnt,
			hdp2 AS bitmap
		FROM dbo.bettrans AS b WITH(NOLOCK) 
		WHERE custid = @custid 
			AND refno = @refno 
			AND matchid = 29 
			AND bettype = 29
			AND transid NOT IN (SELECT transid FROM @tmpBettrans)
	END
	
	INSERT INTO @tmpResults(winlostdate, serial, modds, stake, winlost, statusid, playercomm)
	SELECT winlostdate, serial, modds, stake, winlost, statusid, playercomm
	FROM dbo.betparlayresult AS b WITH(NOLOCK) 
	WHERE refno = @refno AND serial NOT IN (SELECT serial FROM @tmpResults)

	----- generate betparlay detail
	IF @minMatchdate < @BalanceUpday
	BEGIN
		;WITH sub AS 
		(
			SELECT ROW_NUMBER() OVER (ORDER BY matchid) RN, matchid FROM @parlay_base
		)
		UPDATE pb
		SET RN = sub.RN
		FROM sub
			INNER JOIN @parlay_base pb ON sub.matchid = pb.matchid

		-- prepare N
		;WITH sub AS (SELECT COUNT(*) cnt FROM @parlay_base)
		UPDATE pb
		SET CNT = sub.cnt, bCNT = t.N
		FROM sub , @parlay_base pb , @tmpBettrans t
		
		IF NOT EXISTS(SELECT 1 FROM @parlay_base WHERE cnt <> bCnt)
		BEGIN
			INSERT INTO @betParlayDetail
				(RefNo, Serial, matchid )
			SELECT 
				pb.RefNo, rc.Serial, matchid
			FROM
				@parlay_base pb
				INNER JOIN @tmpBettrans tb ON pb.refno = tb.refno
				INNER JOIN dbo.RefCombination rc ON pb.RN = rc.seq AND pb.CNT = rc.N AND (tb.bitmap&rc.bitmap) > 0
		END	
	END
	ELSE
	BEGIN
		INSERT INTO @betParlayDetail(RefNo, Serial, matchid )
		SELECT refno, serial, matchid
		FROM betParlayDetail WITH(NOLOCK)
		WHERE refno = @refno
	END

	----- get homeid, awayid
	IF @MinMatchdate < @BalanceUpday
	BEGIN
		INSERT INTO @tmpMatch
		SELECT
			p.serial,
			homeid,
			awayid
		FROM @tmpResults p 
			INNER JOIN @betParlayDetail b ON p.Serial = b.Serial
			INNER JOIN DBARC.BODB_Archive.dbo.match_bk m WITH (NOLOCK) ON b.matchid = m.matchid	
		WHERE p.statusid <> 113
	END

	IF @MinMatchdate <= @MoveBetDay
	BEGIN
		INSERT INTO @tmpMatch
		SELECT
			p.serial,
			homeid,
			awayid
		FROM @tmpResults p 
			INNER JOIN @betParlayDetail b ON p.Serial = b.Serial
			INNER JOIN dbo.match14 m WITH (NOLOCK) ON b.matchid = m.matchid	
		WHERE p.statusid <> 113
	END

	IF @MaxMatchdate > @MoveBetDay
	BEGIN
		INSERT INTO @tmpMatch
		SELECT
			p.serial,
			homeid,
			awayid
		FROM @tmpResults p 
			INNER JOIN @betParlayDetail b ON p.Serial = b.Serial
			INNER JOIN dbo.match m WITH (NOLOCK) ON b.matchid = m.matchid	
		WHERE p.statusid <> 113
	END
	
	---- calculate outstanding
	SELECT @Outstanding = MAX(stake)
	FROM @tmpBettrans

	SELECT @Outstanding = @Outstanding - ISNULL(SUM(stake),0)
	FROM @tmpResults
	WHERE statusID NOT IN (0,1)

	-- return combo detail
	SELECT 
		winlostdate,
		0 transid,
		serial,
		statusid,	
		CASE statusid 
			WHEN 101 THEN 'REJECT'
			WHEN 102 THEN 'VOID'
			WHEN 103 THEN 'REFUND'
			WHEN 111 THEN 'DRAW'
			WHEN 112 THEN 'WON' 
			ELSE '' 
		END AS status,
		modds,
		stake,
		winlost - stake AS winlost,
		playercomm
	FROM @tmpResults
	WHERE statusid NOT IN (0, 1, 113)

	UNION ALL

	SELECT 
		winlostdate,	
		0 AS transid,	
		0 AS serial,
		113 AS statusid,	
		'LOSE' AS status,
		0 AS modds,	
		SUM(stake) AS stake,	
		SUM(winlost - stake) AS winlost,
		SUM(playercomm) AS playercomm
	FROM @tmpResults
	WHERE statusid = 113
	GROUP BY winlostdate 
	ORDER BY winlostdate ASC

	SELECT * FROM @tmpMatch
END



GO
GRANT EXECUTE ON [dbo].[Acc_BetlistCombinationParlay_Details] TO [bodbDownlineNet]
GO
GRANT EXECUTE ON [dbo].[Acc_BetlistCombinationParlay_Details] TO [bodbDownlineNetView]
GO
GRANT EXECUTE ON [dbo].[Acc_BetlistCombinationParlay_Details] TO [bodbAdminNet]
GO
GRANT EXECUTE ON [dbo].[Acc_BetlistCombinationParlay_Details] TO [bodbExtAccNet]
GO
GRANT VIEW DEFINITION ON [dbo].[Acc_BetlistCombinationParlay_Details] TO [vnteam] 

