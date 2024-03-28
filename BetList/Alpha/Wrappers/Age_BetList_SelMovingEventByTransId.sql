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

	INSERT INTO @SportBettype
	SELECT DISTINCT BetType, EventType
	FROM dbo.f_SportBettypeMatrix_Sel(1, 0, 0, 2, '', '', @IsTest)

	INSERT INTO #MemBetTicket
	SELECT TransId = CASE 
						WHEN (b.bettype = 29 AND ISNULL(b.betid, 0) > 0) THEN b.betid
						ELSE b.transid
					END
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
		,ADiscount = b.discount
		,MDiscount = b.adiscount
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
	INSERT INTO #MemBetTicket
	SELECT TransId = b.transid
		,RefNo = b.refno
		,CustId = b.custid
		,Username = b.username
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
		,ADiscount = b.discount
		,MDiscount = b.adiscount
		,SDiscount = b.sdiscount
		,LiveIndicator = b.liveindicator
		,LiveHomeScore = b.livehomescore
		,LiveAwayScore = b.liveawayscore
		,FinalHomeScore = 0
		,FinalAwayScore = 0
		,HtHomeScore = 0
		,HtAwayScore = 0
		,Ip = b.ip
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
	FROM dbo.bettrans AS b WITH (NOLOCK)
		INNER JOIN dbo.outright AS odds WITH (NOLOCK) ON b.matchid = odds.orid
		INNER JOIN dbo.league l WITH (NOLOCK) ON odds.leagueid = l.leagueid
	WHERE b.TransId = @TransId
		AND b.CustId = @CustId
		AND b.bettype = 10

	-- Get original odds for Mix Parlay and final odds, boost rate for Mix Parlay Boost Bonus
	IF EXISTS (SELECT 1 FROM #MemBetTicket WHERE BetType = 29 AND BetTeam = '1')
	BEGIN
		-- Running/Waiting
		DECLARE @TmpData TABLE (
			RefNo		BIGINT,
			BoostRate	MONEY)

		INSERT INTO @TmpData
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
		INSERT INTO @TmpParlayData
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
		INSERT INTO @TmpParlayData
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
			b.TransDesc = CONVERT(VARCHAR(20), ISNULL(bpr.ExtraValue, ''))
		FROM #MemBetTicket AS b
			INNER JOIN dbo.BetParlayResult AS bpr WITH (NOLOCK) ON bpr.RefNo = b.RefNo
		WHERE b.BetType = 29
			AND b.BetTeam = '1'
			AND b.Status NOT IN ('Running', 'Waiting')
	END

	IF NOT EXISTS (SELECT 1 FROM #MemBetTicket)--bettrans14
	BEGIN
		INSERT INTO #MemBetTicket
		SELECT TransId = CASE 
							WHEN (b.bettype = 29 AND ISNULL(b.betid, 0) > 0) THEN b.betid
						ELSE b.transid
					END
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
			,ADiscount = b.discount
			,MDiscount = b.adiscount
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
		FROM dbo.bettrans14 AS b WITH (NOLOCK)
			INNER JOIN @SportBettype AS s ON b.bettype = s.bettype
			LEFT JOIN dbo.match14 AS m WITH (NOLOCK) ON b.matchid = m.matchid
			LEFT JOIN dbo.League AS le WITH (NOLOCK) ON m.leagueID = le.leagueID
		WHERE b.custid = @CustId
			AND b.TransID = @TransId
			AND s.EventType IN (0, 1)

		-- Outright
		INSERT INTO #MemBetTicket
		SELECT TransId = b.transid
			,RefNo = b.refno
			,CustId = b.custid
			,Username = b.username
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
			,ADiscount = b.discount
			,MDiscount = b.adiscount
			,SDiscount = b.sdiscount
			,LiveIndicator = b.liveindicator
			,LiveHomeScore = b.livehomescore
			,LiveAwayScore = b.liveawayscore
			,FinalHomeScore = 0
			,FinalAwayScore = 0
			,HtHomeScore = 0
			,HtAwayScore = 0
			,Ip = b.ip
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
		FROM dbo.bettrans14 AS b WITH (NOLOCK)
			INNER JOIN dbo.outright14 AS odds WITH (NOLOCK) ON b.matchid = odds.orid
			INNER JOIN dbo.league l WITH (NOLOCK) ON odds.leagueid = l.leagueid
		WHERE b.TransId = @TransId
			AND b.CustId = @CustId
			AND b.bettype = 10

		-- Get original odds for Mix Parlay and final odds, boost rate for Mix Parlay Boost Bonus
		IF EXISTS (SELECT 1 FROM #MemBetTicket WHERE BetType = 29 AND BetTeam = '1')
		BEGIN
			UPDATE b
			SET
				b.Odds = bpr.Odds,
				b.Modds = bpr.mOdds,
				b.TransDesc = CONVERT(VARCHAR(20), ISNULL(bpr.ExtraValue, ''))
			FROM #MemBetTicket AS b
				INNER JOIN dbo.BetParlayResult AS bpr WITH (NOLOCK) ON bpr.RefNo = b.RefNo
			WHERE b.BetType = 29
				AND b.BetTeam = '1'
				AND b.Status NOT IN ('Running', 'Waiting')
		END
	END

	IF NOT EXISTS (SELECT 1 FROM #MemBetTicket)--Bk
	BEGIN
		INSERT INTO #MemBetTicket
		SELECT TransId = CASE 
							WHEN (b.bettype = 29 AND ISNULL(b.betid, 0) > 0) THEN b.betid
							ELSE b.transid
						END
			,RefNo = b.refno
			,CustId = b.custid
			,Username = c.username
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
			,ADiscount = b.discount
			,MDiscount = b.adiscount
			,SDiscount = b.sdiscount
			,LiveIndicator = b.liveindicator
			,LiveHomeScore = b.livehomescore
			,LiveAwayScore = b.liveawayscore
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
			,BetCheck = ISNULL(b.betcheck, '')
			,ComStatus = CASE WHEN b.comstatus = '1' THEN '1' ELSE '0' END
			,TransDesc = ISNULL(b.transdesc, '')
			,OddsSpread = ISNULL(b.oddsspread, 0)
			,BetdaqId = ISNULL(b.betdaqid, -1)
			,ExtraInfo = ISNULL(b.ExtraInfo, '')
			,DeviceType = b.DeviceType
			,LeagueGroupId = le.LeagueGroupId
		FROM bodb_Archive.dbo.bettrans_bk AS b WITH (NOLOCK)
			CROSS APPLY bodb02.dbo.f_IP_Decompress(b.Ip) AS dp
			INNER JOIN @SportBettype AS s ON b.bettype = s.bettype
			INNER JOIN dbo.Customer AS c WITH (NOLOCK) ON c.custid = b.custid
			LEFT JOIN bodb_Archive.dbo.match_bk AS m WITH (NOLOCK) ON b.matchid = m.matchid
			LEFT JOIN dbo.League AS le WITH (NOLOCK) ON m.leagueid = le.leagueid
		WHERE b.custid = @CustId
			AND b.TransID = @TransId
			AND s.EventType IN (0, 1)

		-- Outright
		INSERT INTO #MemBetTicket
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
			,ADiscount = b.discount
			,MDiscount = b.adiscount
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
			UPDATE b
			SET
				b.Odds = bpr.Odds,
				b.Modds = bpr.mOdds,
				b.TransDesc = CONVERT(VARCHAR(20), ISNULL(bpr.ExtraValue, ''))
			FROM #MemBetTicket AS b
				INNER JOIN bodb_Archive.dbo.BetParlayResult AS bpr WITH (NOLOCK) ON bpr.RefNo = b.RefNo
			WHERE b.BetType = 29
				AND b.BetTeam = '1'
				AND b.Status NOT IN ('Running', 'Waiting')
		END
	END

	SELECT *
	FROM #MemBetTicket

	DROP TABLE #MemBetTicket
END
GO
