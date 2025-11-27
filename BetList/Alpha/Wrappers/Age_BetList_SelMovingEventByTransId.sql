/*<info serverAlias="DBACC-bodb02" executers="wsv_alp, wsv_alpv" viewers="" isFunction="0" isNested="0"></info>*/

ALTER PROCEDURE [dbo].[Age_BetList_SelMovingEventByTransId]
	@CustId		INT,
	@TransId	BIGINT
AS

/*
	Created: 20220404@[Razor]
	Task: [Get Moving Event Date ticket]
	DB: DBACC.bodb02

	Revisions:
		- 20220404@Razor: Init [Redmine: #171070]
		- 20231004@Kos: Support Parlay Boost [Redmine: #194992]
		- 20231019@Razor: Return Device Type info [Redmine: #192667]
		- 20231129@Razor: Support Project 777 - return LeagueGroupId [Redmine: #194591]
		- 20241218@Razor: Support Direct Member [Redmine: #211969]
		- 20251107@Virgil: Support BetBuilder+ Hybrid Parlay [Redmine: #242378]
*/

BEGIN
	SET NOCOUNT ON;

	-- Check SP Version
	DECLARE @IsTest BIT = 0
	SELECT @IsTest = dbo.f_CheckSPVersion(@@PROCID)

	CREATE TABLE #MemBetTicket (
		TransId				BIGINT
		, RefNo				BIGINT
		, CustId			INT
		, Username			NVARCHAR(50)
		, SportType			SMALLINT
		, BetType			SMALLINT
		, BetId				BIGINT
		, BetTeam			NVARCHAR(20)
		, Hdp1				SMALLMONEY
		, Hdp2				SMALLMONEY
		, OddsType			TINYINT
		, OddsId			INT
		, Odds				MONEY
		, MOdds				MONEY
		, Stake				MONEY
		, Actual_Stake		MONEY
		, Status			NVARCHAR(10)
		, SettlementStatus	TINYINT
		, TransDate			DATETIME
		, WinLostDate		SMALLDATETIME
		, WinLost			MONEY
		, AWinLost			MONEY
		, MWinLost			MONEY
		, SWinLost			MONEY
		, PlayerComm		MONEY
		, Comm				MONEY
		, AComm				MONEY
		, SComm				MONEY
		, APositionTaking	SMALLMONEY
		, MPositionTaking	SMALLMONEY
		, SPositionTaking	SMALLMONEY
		, TPositionTaking	SMALLMONEY
		, ADiscount			SMALLMONEY
		, MDiscount			SMALLMONEY
		, SDiscount			SMALLMONEY
		, LiveIndicator		BIT
		, LiveHomeScore		SMALLINT
		, LiveAwayScore		SMALLINT
		, FinalHomeScore	SMALLINT
		, FinalAwayScore	SMALLINT
		, HtHomeScore		SMALLINT
		, HtAwayScore		SMALLINT
		, Ip				VARCHAR(45)
		, LeagueId			INT
		, MatchId			INT
		, MatchCode			NVARCHAR(50)
		, EventDate			DATETIME
		, HomeId			INT
		, AwayId			INT
		, BetStatus			NVARCHAR(50)
		, IsNeutral			BIT
		, ShowTime			NVARCHAR(50)
		, BetCheck			NVARCHAR(50)
		, ComStatus			NVARCHAR(20)
		, TransDesc			NVARCHAR(1000)
		, OddsSpread		MONEY
		, BetdaqId			BIGINT
		, ExtraInfo			VARCHAR(1000)
		, DeviceType		TINYINT
		, LeagueGroupId		SMALLINT
	);

	DECLARE @SportBettype TABLE(Bettype SMALLINT, EventType TINYINT)

	INSERT INTO @SportBettype (Bettype, EventType)
	SELECT DISTINCT BetType, EventType
	FROM dbo.f_SportBettypeMatrix_Sel(1, 0, 0, 2, '', '', @IsTest)

	INSERT INTO #MemBetTicket (
		TransId, RefNo, CustId, Username, SportType, BetType, BetId, BetTeam, Hdp1, Hdp2, OddsType, OddsId, Odds, MOdds, Stake, Actual_Stake, Status, SettlementStatus, TransDate, WinLostDate, WinLost, AWinLost, MWinLost,
		SWinLost, PlayerComm, Comm, AComm, SComm, APositionTaking, MPositionTaking, SPositionTaking, TPositionTaking, ADiscount, MDiscount, SDiscount, LiveIndicator, LiveHomeScore, LiveAwayScore, FinalHomeScore, FinalAwayScore, HtHomeScore, HtAwayScore,
		Ip, LeagueId, MatchId, MatchCode, EventDate, HomeId, AwayId, BetStatus, IsNeutral, ShowTime, BetCheck, ComStatus, TransDesc, OddsSpread, BetdaqId, ExtraInfo, DeviceType, LeagueGroupId
	)
	SELECT TransId = b.transid
		,RefNo = b.refno
		,CustId = b.custid
		,Username = b.username
		,SportType = m.sporttype
		,BetType = b.bettype
		,BetId = ISNULL(b.betid, 0)
		,b.betteam
		,Hdp1 = b.hdp1
		,Hdp2 = b.hdp2
		,OddsType = b.oddstype
		,OddsId = b.oddsid
		,Odds = b.Odds
		,MOdds = b.modds
		,Stake = b.stake
		,Actual_Stake = b.actual_stake
		,Status = b.status
		,SettlementStatus = ISNULL(m.SettlementStatus, 0)
		,TransDate = b.transdate
		,WinLostDate = b.winlostdate
		,WinLost = b.winlost - b.actual_stake
		,AWinLost = b.awinLost
		,MWinLost = b.mwinLost
		,SWinLost = b.SwinLost
		,PlayerComm = b.playercomm
		,Comm = b.comm - b.playercomm
		,AComm = b.acomm - b.comm
		,SComm = b.scomm - b.acomm
		,APositionTaking = b.APositiontaking
		,MPositionTaking = b.MPositiontaking
		,SPositionTaking = b.SPositiontaking
		,TPositionTaking = b.TPositiontaking
		,ADiscount = CASE
						WHEN b.recommend IN (-3, -4) THEN 0
						ELSE b.discount
					END
		,MDiscount = CASE
						WHEN b.mrecommend = -4 THEN 0
						ELSE b.adiscount
					END
		,SDiscount = b.sdiscount
		,LiveIndicator = b.liveindicator
		,LiveHomeScore = b.livehomescore
		,LiveAwayScore = b.liveawayscore
		,FinalHomeScore = m.finalhomescore
		,FinalAwayScore = m.finalawayscore
		,HtHomeScore = m.hthomescore
		,HtAwayScore = m.htawayscore
		,Ip = b.ip
		,LeagueId = m.leagueid
		,MatchId = m.matchid
		,MatchCode = m.matchcode
		,EventDate = m.GlobalShowTime
		,HomeId = m.homeid
		,AwayId = m.awayid
		,BetStatus = m.betstatus
		,IsNeutral = ISNULL(m.IsNeutral, 0)
		,ShowTime = ISNULL(m.showtime, '')
		,BetCheck = ISNULL(b.betcheck, '')
		,ComStatus = CASE WHEN b.comstatus = '1' THEN '1' ELSE '0' END
		,TransDesc = ISNULL(b.transdesc, '')
		,OddsSpread = ISNULL(b.oddsspread, 0)
		,BetdaqId = ISNULL(b.betdaqid, -1)
		,ExtraInfo = ISNULL(b.ExtraInfo, '')
		,DeviceType = b.DeviceType
		,LeagueGroupId = le.LeagueGroupId
	FROM dbo.bettrans AS b WITH (NOLOCK)
		INNER JOIN @SportBettype AS s ON b.bettype = s.bettype
		LEFT JOIN dbo.match AS m WITH (NOLOCK) ON b.matchid = m.matchid
		LEFT JOIN dbo.League AS le WITH (NOLOCK) ON m.leagueID = le.leagueID
	WHERE b.TransId = @TransId
		AND b.CustId = @CustId
		AND s.EventType IN (0, 1)

	-- Outright
	INSERT INTO #MemBetTicket (
		TransId, RefNo, CustId, Username, SportType, BetType, BetId, BetTeam, Hdp1, Hdp2, OddsType, OddsId, Odds, MOdds, Stake, Actual_Stake, Status, SettlementStatus, TransDate, WinLostDate, WinLost, AWinLost, MWinLost,
		SWinLost, PlayerComm, Comm, AComm, SComm, APositionTaking, MPositionTaking, SPositionTaking, TPositionTaking, ADiscount, MDiscount, SDiscount, LiveIndicator, LiveHomeScore, LiveAwayScore, FinalHomeScore, FinalAwayScore, HtHomeScore, HtAwayScore,
		Ip, LeagueId, MatchId, MatchCode, EventDate, HomeId, AwayId, BetStatus, IsNeutral, ShowTime, BetCheck, ComStatus, TransDesc, OddsSpread, BetdaqId, ExtraInfo, DeviceType, LeagueGroupId
	)
	SELECT TransId = otr.transid
			,RefNo = otr.refno
			,CustId = otr.custid
			,Username = otr.username
			,SportType = l.sporttype
			,BetType = otr.bettype
			,BetId = ISNULL(otr.betid, 0)
			,otr.betteam
			,Hdp1 = otr.hdp1
			,Hdp2 = otr.hdp2
			,OddsType = otr.oddstype
			,OddsId = otr.oddsid
			,Odds = otr.Odds
			,MOdds = otr.modds
			,Stake = otr.stake
			,Actual_Stake = otr.actual_stake
			,Status = otr.status
			,SettlementStatus = 0
			,TransDate = otr.transdate
			,WinLostDate = otr.winlostdate
			,WinLost = otr.winlost - otr.actual_stake
			,AWinLost = otr.awinLost
			,MWinLost = otr.mwinLost
			,SWinLost = otr.SwinLost
			,PlayerComm = otr.playercomm
			,Comm = otr.comm - otr.playercomm
			,AComm = otr.acomm - otr.comm
			,SComm = otr.scomm - otr.acomm
			,APositionTaking = otr.APositiontaking
			,MPositionTaking = otr.MPositiontaking
			,SPositionTaking = otr.SPositiontaking
			,TPositionTaking = otr.TPositiontaking
			,ADiscount = CASE
							WHEN otr.recommend IN (-3, -4) THEN 0
							ELSE otr.discount
						END
			,MDiscount = CASE
							WHEN otr.mrecommend = -4 THEN 0
							ELSE otr.adiscount
						END
			,SDiscount = otr.sdiscount
			,LiveIndicator = otr.liveindicator
			,LiveHomeScore = otr.livehomescore
			,LiveAwayScore = otr.liveawayscore
			,FinalHomeScore = 0
			,FinalAwayScore = 0
			,HtHomeScore = 0
			,HtAwayScore = 0
			,Ip = otr.ip
			,LeagueId = odds.leagueid
			,MatchId = otr.matchid
			,MatchCode = odds.matchcode
			,EventDate = odds.eventdate
			,HomeId = 0
			,AwayId = odds.teamid
			,BetStatus = ''
			,IsNeutral = 0
			,ShowTime = ''
			,BetCheck = ISNULL(otr.betcheck, '')
			,ComStatus = CASE WHEN otr.comstatus = '1' THEN '1' ELSE '0' END
			,TransDesc = ''
			,OddsSpread = 0
			,BetdaqId = -1
			,ExtraInfo = ''
			,DeviceType = otr.DeviceType
			,LeagueGroupId = l.LeagueGroupId
		FROM dbo.bettrans AS otr WITH (NOLOCK)
			INNER JOIN dbo.outright AS odds WITH (NOLOCK) ON otr.matchid = odds.orid
			INNER JOIN dbo.league l WITH (NOLOCK) ON odds.leagueid = l.leagueid
		WHERE otr.TransId = @TransId
			AND otr.CustId = @CustId
			AND otr.bettype = 10

	-- Get original odds for Mix Parlay and final odds, boost rate for Mix Parlay Boost Bonus
	IF EXISTS (SELECT 1 FROM #MemBetTicket WHERE BetType = 29 AND BetTeam = '1')
	BEGIN
		-- Running/Waiting
		DECLARE @TmpData TABLE (
			RefNo		BIGINT,
			BoostRate	MONEY)

		INSERT INTO @TmpData (RefNo, BoostRate)
		SELECT
			b.refno,
			CASE
				WHEN b.bettype = 29 AND b.betteam = 1 AND b.oddsspread = 2 THEN
					ISNULL(CAST(('<xml>' + b.ExtraInfo + '</xml>') AS XML).value('data(/xml/p1/@bbp)[1]','MONEY'), 0)
				ELSE 0
			END AS BoostRate
		FROM #MemBetTicket AS b
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
		FROM @TmpData AS b
			INNER JOIN dbo.BetParlayDetail AS bpd WITH (NOLOCK) ON bpd.RefNo = b.RefNo
		GROUP BY
			b.RefNo,
			b.BoostRate

		-- Mix Parlay which having no settled sub ticket
		INSERT INTO @TmpParlayData (RefNo, Odds, MOdds)
		SELECT
			b.RefNo,
			dbo.PRODUCT(bm.odds) AS Odds,
			dbo.PRODUCT(bm.odds) * (b.BoostRate + 1) - b.BoostRate AS MOdds
		FROM @TmpData AS b
			INNER JOIN dbo.bettransm AS bm WITH (NOLOCK) ON bm.refno = b.RefNo
		WHERE NOT EXISTS (SELECT 1 FROM @TmpParlayData WHERE RefNo = b.RefNo)
		GROUP BY
			b.RefNo,
			b.BoostRate

		UPDATE b
		SET
			b.Odds = td.Odds,
			b.MOdds = td.MOdds
		FROM #MemBetTicket AS b
			INNER JOIN @TmpParlayData AS td ON td.RefNo = b.RefNo

		-- Settled
		UPDATE b
		SET
			b.Odds = bpr.Odds,
			b.Modds = bpr.mOdds,
			b.TransDesc = IIF(b.oddsSpread = 3, b.transdesc, CONVERT(VARCHAR(20), ISNULL(bpr.ExtraValue, '')))
		FROM #MemBetTicket AS b
			INNER JOIN dbo.BetParlayResult AS bpr WITH (NOLOCK) ON bpr.RefNo = b.RefNo
		WHERE b.BetType = 29
			AND b.BetTeam = '1'
			AND b.Status NOT IN ('Running', 'Waiting')
	END

	IF NOT EXISTS (SELECT 1 FROM #MemBetTicket)--bettrans14
	BEGIN
		INSERT INTO #MemBetTicket (
			TransId, RefNo, CustId, Username, SportType, BetType, BetId, BetTeam, Hdp1, Hdp2, OddsType, OddsId, Odds, MOdds, Stake, Actual_Stake, Status, SettlementStatus, TransDate, WinLostDate, WinLost, AWinLost, MWinLost,
			SWinLost, PlayerComm, Comm, AComm, SComm, APositionTaking, MPositionTaking, SPositionTaking, TPositionTaking, ADiscount, MDiscount, SDiscount, LiveIndicator, LiveHomeScore, LiveAwayScore, FinalHomeScore, FinalAwayScore, HtHomeScore, HtAwayScore,
			Ip, LeagueId, MatchId, MatchCode, EventDate, HomeId, AwayId, BetStatus, IsNeutral, ShowTime, BetCheck, ComStatus, TransDesc, OddsSpread, BetdaqId, ExtraInfo, DeviceType, LeagueGroupId
		)
		SELECT TransId = b14.transid
				,RefNo = b14.refno
				,CustId = b14.custid
				,Username = b14.username
				,SportType = m.sporttype
				,BetType = b14.bettype
				,BetId = ISNULL(b14.betid, 0)
				,b14.betteam
				,Hdp1 = b14.hdp1
				,Hdp2 = b14.hdp2
				,OddsType = b14.oddstype
				,OddsId = b14.oddsid
				,Odds = b14.Odds
				,MOdds = b14.modds
				,Stake = b14.stake
				,Actual_Stake = b14.actual_stake
				,Status = b14.status
				,SettlementStatus = 0
				,TransDate = b14.transdate
				,WinLostDate = b14.winlostdate
				,WinLost = b14.winlost - b14.actual_stake
				,AWinLost = b14.awinLost
				,MWinLost = b14.mwinLost
				,SWinLost = b14.SwinLost
				,PlayerComm = b14.playercomm
				,Comm = b14.comm - b14.playercomm
				,AComm = b14.acomm - b14.comm
				,SComm = b14.scomm - b14.acomm
				,APositionTaking = b14.APositiontaking
				,MPositionTaking = b14.MPositiontaking
				,SPositionTaking = b14.SPositiontaking
				,TPositionTaking = b14.TPositiontaking
				,ADiscount = CASE
								WHEN b14.recommend IN (-3, -4) THEN 0
								ELSE b14.discount
							END
				,MDiscount = CASE
								WHEN b14.mrecommend = -4 THEN 0
								ELSE b14.adiscount
							END
				,SDiscount = b14.sdiscount
				,LiveIndicator = b14.liveindicator
				,LiveHomeScore = b14.livehomescore
				,LiveAwayScore = b14.liveawayscore
				,FinalHomeScore = m.finalhomescore
				,FinalAwayScore = m.finalawayscore
				,HtHomeScore = m.hthomescore
				,HtAwayScore = m.htawayscore
				,Ip = b14.ip
				,LeagueId = m.leagueid
				,MatchId = m.matchid
				,MatchCode = m.matchcode
				,EventDate = m.GlobalShowTime
				,HomeId = m.homeid
				,AwayId = m.awayid
				,BetStatus = m.betstatus
				,IsNeutral = ISNULL(m.IsNeutral, 0)
				,ShowTime = ISNULL(m.showtime, '')
				,BetCheck = ISNULL(b14.betcheck, '')
				,ComStatus = CASE WHEN b14.comstatus = '1' THEN '1' ELSE '0' END
				,TransDesc = ISNULL(b14.transdesc, '')
				,OddsSpread = ISNULL(b14.oddsspread, 0)
				,BetdaqId = ISNULL(b14.betdaqid, -1)
				,ExtraInfo = ISNULL(b14.ExtraInfo, '')
				,DeviceType = b14.DeviceType
				,LeagueGroupId = le.LeagueGroupId
			FROM dbo.bettrans14 AS b14 WITH (NOLOCK)
				INNER JOIN @SportBettype AS s ON b14.bettype = s.bettype
				LEFT JOIN dbo.match14 AS m WITH (NOLOCK) ON b14.matchid = m.matchid
				LEFT JOIN dbo.League AS le WITH (NOLOCK) ON m.leagueID = le.leagueID
			WHERE b14.custid = @CustId
				AND b14.TransID = @TransId
				AND s.EventType IN (0, 1)

		-- Outright
		INSERT INTO #MemBetTicket (
			TransId, RefNo, CustId, Username, SportType, BetType, BetId, BetTeam, Hdp1, Hdp2, OddsType, OddsId, Odds, MOdds, Stake, Actual_Stake, Status, SettlementStatus, TransDate, WinLostDate, WinLost, AWinLost, MWinLost,
			SWinLost, PlayerComm, Comm, AComm, SComm, APositionTaking, MPositionTaking, SPositionTaking, TPositionTaking, ADiscount, MDiscount, SDiscount, LiveIndicator, LiveHomeScore, LiveAwayScore, FinalHomeScore, FinalAwayScore, HtHomeScore, HtAwayScore,
			Ip, LeagueId, MatchId, MatchCode, EventDate, HomeId, AwayId, BetStatus, IsNeutral, ShowTime, BetCheck, ComStatus, TransDesc, OddsSpread, BetdaqId, ExtraInfo, DeviceType, LeagueGroupId
		)
		SELECT TransId = otr14.transid
				,RefNo = otr14.refno
				,CustId = otr14.custid
				,Username = otr14.username
				,SportType = l.sporttype
				,BetType = otr14.bettype
				,BetId = ISNULL(otr14.betid, 0)
				,otr14.betteam
				,Hdp1 = otr14.hdp1
				,Hdp2 = otr14.hdp2
				,OddsType = otr14.oddstype
				,OddsId = otr14.oddsid
				,Odds = otr14.Odds
				,MOdds = otr14.modds
				,Stake = otr14.stake
				,Actual_Stake = otr14.actual_stake
				,Status = otr14.status
				,SettlementStatus = 0
				,TransDate = otr14.transdate
				,WinLostDate = otr14.winlostdate
				,WinLost = otr14.winlost - otr14.actual_stake
				,AWinLost = otr14.awinLost
				,MWinLost = otr14.mwinLost
				,SWinLost = otr14.SwinLost
				,PlayerComm = otr14.playercomm
				,Comm = otr14.comm - otr14.playercomm
				,AComm = otr14.acomm - otr14.comm
				,SComm = otr14.scomm - otr14.acomm
				,APositionTaking = otr14.APositiontaking
				,MPositionTaking = otr14.MPositiontaking
				,SPositionTaking = otr14.SPositiontaking
				,TPositionTaking = otr14.TPositiontaking
				,ADiscount = CASE
								WHEN otr14.recommend IN (-3, -4) THEN 0
								ELSE otr14.discount
							END
				,MDiscount = CASE
								WHEN otr14.mrecommend = -4 THEN 0
								ELSE otr14.adiscount
							END
				,SDiscount = otr14.sdiscount
				,LiveIndicator = otr14.liveindicator
				,LiveHomeScore = otr14.livehomescore
				,LiveAwayScore = otr14.liveawayscore
				,FinalHomeScore = 0
				,FinalAwayScore = 0
				,HtHomeScore = 0
				,HtAwayScore = 0
				,Ip = otr14.ip
				,LeagueId = odds.leagueid
				,MatchId = otr14.matchid
				,MatchCode = odds.matchcode
				,EventDate = odds.eventdate
				,HomeId = 0
				,AwayId = odds.teamid
				,BetStatus = ''
				,IsNeutral = 0
				,ShowTime = ''
				,BetCheck = ISNULL(otr14.betcheck, '')
				,ComStatus = CASE WHEN otr14.comstatus = '1' THEN '1' ELSE '0' END
				,TransDesc = ''
				,OddsSpread = 0
				,BetdaqId = -1
				,ExtraInfo = ''
				,DeviceType = otr14.DeviceType
				,LeagueGroupId = l.LeagueGroupId
			FROM dbo.bettrans14 AS otr14 WITH (NOLOCK)
				INNER JOIN dbo.outright14 AS odds WITH (NOLOCK) ON otr14.matchid = odds.orid
				INNER JOIN dbo.league l WITH (NOLOCK) ON odds.leagueid = l.leagueid
			WHERE otr14.TransId = @TransId
				AND otr14.CustId = @CustId
				AND otr14.bettype = 10

		-- Get original odds for Mix Parlay and final odds, boost rate for Mix Parlay Boost Bonus
		IF EXISTS (SELECT 1 FROM #MemBetTicket WHERE BetType = 29 AND BetTeam = '1')
		BEGIN
			UPDATE b
			SET
				b.Odds = bpr.Odds,
				b.Modds = bpr.mOdds,
				b.TransDesc = IIF(b.oddsSpread = 3, b.transdesc, CONVERT(VARCHAR(20), ISNULL(bpr.ExtraValue, '')))
			FROM #MemBetTicket AS b
				INNER JOIN dbo.BetParlayResult AS bpr WITH (NOLOCK) ON bpr.RefNo = b.RefNo
			WHERE b.BetType = 29
				AND b.BetTeam = '1'
				AND b.Status NOT IN ('Running', 'Waiting')
		END
	END

	IF NOT EXISTS (SELECT 1 FROM #MemBetTicket)--Bk
	BEGIN
		INSERT INTO #MemBetTicket (
			TransId, RefNo, CustId, Username, SportType, BetType, BetId, BetTeam, Hdp1, Hdp2, OddsType, OddsId, Odds, MOdds, Stake, Actual_Stake, Status, SettlementStatus, TransDate, WinLostDate, WinLost, AWinLost, MWinLost,
			SWinLost, PlayerComm, Comm, AComm, SComm, APositionTaking, MPositionTaking, SPositionTaking, TPositionTaking, ADiscount, MDiscount, SDiscount, LiveIndicator, LiveHomeScore, LiveAwayScore, FinalHomeScore, FinalAwayScore, HtHomeScore, HtAwayScore,
			Ip, LeagueId, MatchId, MatchCode, EventDate, HomeId, AwayId, BetStatus, IsNeutral, ShowTime, BetCheck, ComStatus, TransDesc, OddsSpread, BetdaqId, ExtraInfo, DeviceType, LeagueGroupId
		)
		SELECT TransId = bk.transid
				,RefNo = bk.refno
				,CustId = bk.custid
				,Username = c.username
				,SportType = m.sporttype
				,BetType = bk.bettype
				,BetId = ISNULL(bk.betid, 0)
				,bk.betteam
				,Hdp1 = bk.hdp1
				,Hdp2 = bk.hdp2
				,OddsType = bk.oddstype
				,OddsId = bk.oddsid
				,Odds = bk.Odds
				,MOdds = bk.modds
				,Stake = bk.stake
				,Actual_Stake = bk.actual_stake
				,Status = bk.status
				,SettlementStatus = 0
				,TransDate = bk.transdate
				,WinLostDate = bk.winlostdate
				,WinLost = bk.winlost - bk.actual_stake
				,AWinLost = bk.awinLost
				,MWinLost = bk.mwinLost
				,SWinLost = bk.SwinLost
				,PlayerComm = bk.playercomm
				,Comm = bk.comm - bk.playercomm
				,AComm = bk.acomm - bk.comm
				,SComm = bk.scomm - bk.acomm
				,APositionTaking = bk.APositiontaking
				,MPositionTaking = bk.MPositiontaking
				,SPositionTaking = bk.SPositiontaking
				,TPositionTaking = bk.TPositiontaking
				,ADiscount = CASE
								WHEN bk.recommend IN (-3, -4) THEN 0
								ELSE bk.discount
							END
				,MDiscount = CASE
								WHEN bk.mrecommend = -4 THEN 0
								ELSE bk.adiscount
							END
				,SDiscount = bk.sdiscount
				,LiveIndicator = bk.liveindicator
				,LiveHomeScore = bk.livehomescore
				,LiveAwayScore = bk.liveawayscore
				,FinalHomeScore = m.finalhomescore
				,FinalAwayScore = m.finalawayscore
				,HtHomeScore = m.hthomescore
				,HtAwayScore = m.htawayscore
				,Ip = dp.ip
				,LeagueId = m.leagueid
				,MatchId = m.matchid
				,MatchCode = m.matchcode
				,EventDate = m.GlobalShowTime
				,HomeId = m.homeid
				,AwayId = m.awayid
				,BetStatus = m.betstatus
				,IsNeutral = ISNULL(m.IsNeutral, 0)
				,ShowTime = ISNULL(m.showtime, '')
				,BetCheck = ISNULL(bk.betcheck, '')
				,ComStatus = CASE WHEN bk.comstatus = '1' THEN '1' ELSE '0' END
				,TransDesc = ISNULL(bk.transdesc, '')
				,OddsSpread = ISNULL(bk.oddsspread, 0)
				,BetdaqId = ISNULL(bk.betdaqid, -1)
				,ExtraInfo = ISNULL(bk.ExtraInfo, '')
				,DeviceType = bk.DeviceType
				,LeagueGroupId = le.LeagueGroupId
			FROM bodb_Archive.dbo.bettrans_bk AS bk WITH (NOLOCK)
				CROSS APPLY bodb02.dbo.f_IP_Decompress(bk.Ip) AS dp
				INNER JOIN @SportBettype AS s ON bk.bettype = s.bettype
				INNER JOIN dbo.Customer AS c WITH (NOLOCK) ON c.custid = bk.custid
				LEFT JOIN bodb_Archive.dbo.match_bk AS m WITH (NOLOCK) ON bk.matchid = m.matchid
				LEFT JOIN dbo.League AS le WITH (NOLOCK) ON m.leagueid = le.leagueid
			WHERE bk.custid = @CustId
				AND bk.TransID = @TransId
				AND s.EventType IN (0, 1)

		-- Outright
		INSERT INTO #MemBetTicket (
			TransId, RefNo, CustId, Username, SportType, BetType, BetId, BetTeam, Hdp1, Hdp2, OddsType, OddsId, Odds, MOdds, Stake, Actual_Stake, Status, SettlementStatus, TransDate, WinLostDate, WinLost, AWinLost, MWinLost,
			SWinLost, PlayerComm, Comm, AComm, SComm, APositionTaking, MPositionTaking, SPositionTaking, TPositionTaking, ADiscount, MDiscount, SDiscount, LiveIndicator, LiveHomeScore, LiveAwayScore, FinalHomeScore, FinalAwayScore, HtHomeScore, HtAwayScore,
			Ip, LeagueId, MatchId, MatchCode, EventDate, HomeId, AwayId, BetStatus, IsNeutral, ShowTime, BetCheck, ComStatus, TransDesc, OddsSpread, BetdaqId, ExtraInfo, DeviceType, LeagueGroupId
		)
		SELECT TransId = b.transid
			,RefNo = b.refno
			,CustId = b.custid
			,Username = c.username
			,SportType = l.sporttype
			,BetType = b.bettype
			,BetId = ISNULL(b.betid, 0)
			,b.betteam
			,Hdp1 = b.hdp1
			,Hdp2 = b.hdp2
			,OddsType = b.oddstype
			,OddsId = b.oddsid
			,Odds = b.Odds
			,MOdds = b.modds
			,Stake = b.stake
			,Actual_Stake = b.actual_stake
			,Status = b.status
			,SettlementStatus = 0
			,TransDate = b.transdate
			,WinLostDate = b.winlostdate
			,WinLost = b.winlost - b.actual_stake
			,AWinLost = b.awinLost
			,MWinLost = b.mwinLost
			,SWinLost = b.SwinLost
			,PlayerComm = b.playercomm
			,Comm = b.comm - b.playercomm
			,AComm = b.acomm - b.comm
			,SComm = b.scomm - b.acomm
			,APositionTaking = b.APositiontaking
			,MPositionTaking = b.MPositiontaking
			,SPositionTaking = b.SPositiontaking
			,TPositionTaking = b.TPositiontaking
			,ADiscount = CASE
							WHEN b.recommend IN (-3, -4) THEN 0
							ELSE b.discount
						END
			,MDiscount = CASE
							WHEN b.mrecommend = -4 THEN 0
							ELSE b.adiscount
						END
			,SDiscount = b.sdiscount
			,LiveIndicator = b.liveindicator
			,LiveHomeScore = b.livehomescore
			,LiveAwayScore = b.liveawayscore
			,FinalHomeScore = 0
			,FinalAwayScore = 0
			,HtHomeScore = 0
			,HtAwayScore = 0
			,Ip = dp.ip
			,LeagueId = odds.leagueid
			,MatchId = b.matchid
			,MatchCode = odds.matchcode
			,EventDate = odds.eventdate
			,HomeId = 0
			,AwayId = odds.teamid
			,BetStatus = ''
			,IsNeutral = 0
			,ShowTime = ''
			,BetCheck = ISNULL(b.betcheck, '')
			,ComStatus = CASE WHEN b.comstatus = '1' THEN '1' ELSE '0' END
			,TransDesc = ''
			,OddsSpread = 0
			,BetdaqId = -1
			,ExtraInfo = ''
			,DeviceType = b.DeviceType
			,LeagueGroupId = l.LeagueGroupId
		FROM bodb_archive.dbo.bettrans_bk AS b WITH (NOLOCK)
			CROSS APPLY dbo.f_IP_Decompress(b.Ip) AS dp
			INNER JOIN dbo.Customer AS c WITH (NOLOCK) ON c.custid = b.custid
			INNER JOIN bodb_archive.dbo.Outright_bk AS odds WITH (NOLOCK) ON b.matchid = odds.orid
			INNER JOIN dbo.league l WITH (NOLOCK) ON odds.leagueid = l.leagueid
		WHERE b.TransId = @TransId
			AND b.CustId = @CustId
			AND b.bettype = 10

		-- Get original odds for Mix Parlay and final odds, boost rate for Mix Parlay Boost Bonus
		IF EXISTS (SELECT 1 FROM #MemBetTicket WHERE BetType = 29 AND BetTeam = '1')
		BEGIN
			UPDATE bk
			SET
				bk.Odds = bpr.Odds,
				bk.Modds = bpr.mOdds,
				bk.TransDesc = IIF(bk.oddsSpread = 3, bk.transdesc, CONVERT(VARCHAR(20), ISNULL(bpr.ExtraValue, '')))
			FROM #MemBetTicket AS bk
				INNER JOIN bodb_Archive.dbo.BetParlayResult AS bpr WITH (NOLOCK) ON bpr.RefNo = bk.RefNo
			WHERE bk.BetType = 29
				AND bk.BetTeam = '1'
				AND bk.Status NOT IN ('Running', 'Waiting')
		END
	END

	SELECT
		TransId,
		RefNo,
		CustId,
		Username,
		SportType,
		BetType,
		BetId,
		BetTeam,
		Hdp1,
		Hdp2,
		OddsType,
		OddsId,
		Odds,
		MOdds,
		Stake,
		Actual_Stake,
		Status,
		SettlementStatus,
		TransDate,
		WinLostDate,
		WinLost,
		AWinLost,
		MWinLost,
		SWinLost,
		PlayerComm,
		Comm,
		AComm,
		SComm,
		APositionTaking,
		MPositionTaking,
		SPositionTaking,
		TPositionTaking,
		ADiscount,
		MDiscount,
		SDiscount,
		LiveIndicator,
		LiveHomeScore,
		LiveAwayScore,
		FinalHomeScore,
		FinalAwayScore,
		HtHomeScore,
		HtAwayScore,
		Ip,
		LeagueId,
		MatchId,
		MatchCode,
		EventDate,
		HomeId,
		AwayId,
		BetStatus,
		IsNeutral,
		ShowTime,
		BetCheck,
		ComStatus,
		TransDesc,
		OddsSpread,
		BetdaqId,
		ExtraInfo,
		DeviceType,
		LeagueGroupId
	FROM #MemBetTicket

	DROP TABLE #MemBetTicket
END
GO
