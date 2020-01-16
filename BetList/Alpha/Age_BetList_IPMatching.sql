/*<info serverAlias="DBAGE-bodb02" executers="bodbDownlineNet,bodbDownlineNetView" viewers="" isFunction="0" isNested="0"></info>*/

ALTER PROCEDURE [dbo].[Age_BetList_IPMatching]
	@CustId			INT,
	@Ip				VARCHAR(15),
	@Date			SMALLDATETIME,
	@MoveBetsDay	SMALLDATETIME
AS

/*
	Created: 20200116@Kos
	Task: Alpha - Bet List for IP Matching report (Super level only)
	DB: DBAGE.bodb02
	
	Revisions:
		- 20200116@Kos: Created [Redmine: #124701]

*/

BEGIN
	SET NOCOUNT ON;

	-- Check SP Version
	DECLARE @IsTest BIT = 0

	SELECT @IsTest = dbo.f_CheckSPVersion(@@PROCID)

	-- Gather BettypeMatrix
	DECLARE @SportBettype TABLE ( ProductID TINYINT, Bettype SMALLINT, EventType TINYINT, SubProduct VARCHAR(500))

	INSERT INTO @SportBettype
	SELECT ProductID, Bettype, EventType, SubProduct
	FROM dbo.f_SportBettypeMatrix_Sel (1, 0, 0, 2, '', '', @IsTest)
	WHERE BetType NOT IN (10, 29, 38, 301, 302, 303, 304, 901, 902, 903, 904, 911, 912, 913, 914)

	DECLARE @MemBetTicket TABLE (
		TransId				BIGINT,
		RefNo				BIGINT,
		CustId				INT,
		Username			NVARCHAR(50),
		SportType			SMALLINT,
		BetType				SMALLINT,
		BetId				BIGINT,
		BetTeam				NVARCHAR(20),
		Hdp1				SMALLMONEY,
		Hdp2				SMALLMONEY,
		OddsType			TINYINT,
		Odds				MONEY,
		MOdds				MONEY,
		Stake				MONEY,
		Actual_Stake		MONEY,
		Status				NVARCHAR(10),
		SettlementStatus	TINYINT,
		TransDate			DATETIME,
		WinLostDate			SMALLDATETIME,
		WinLost				MONEY,
		AWinLost			MONEY,
		MWinLost			MONEY,
		SWinLost			MONEY,
		PlayerComm			MONEY,
		Comm				MONEY,
		AComm				MONEY,
		SComm				MONEY,
		APositionTaking		SMALLMONEY,
		MPositionTaking		SMALLMONEY,
		SPositionTaking		SMALLMONEY,
		TPositionTaking		SMALLMONEY,
		ADiscount			SMALLMONEY,
		MDiscount			SMALLMONEY,
		SDiscount			SMALLMONEY,
		LiveIndicator		BIT,
		LiveHomeScore		SMALLINT,
		LiveAwayScore		SMALLINT,
		FinalHomeScore		SMALLINT,
		FinalAwayScore		SMALLINT,
		HtHomeScore			SMALLINT,
		HtAwayScore			SMALLINT,
		Ip					NVARCHAR(15),
		LeagueId			INT,
		MatchId				INT,
		MatchCode			NVARCHAR(50),
		EventDate			DATETIME,
		HomeId				INT,
		AwayId				INT,
		BetStatus			NVARCHAR(50),
		IsNeutral			BIT,
		ShowTime			NVARCHAR(50),
		BetCheck			NVARCHAR(50),
		ComStatus			NVARCHAR(20),
		TransDesc			NVARCHAR(1000),
		OddsSpread			MONEY,
		ExtraInfo			VARCHAR(1000),
		Currency			NVARCHAR(50)
	);

	DECLARE @Tickets TABLE (
		TransId		BIGINT,
		RefNo		BIGINT,
		WinLostDate	SMALLDATETIME,
		Product		VARCHAR(30)
	)

	DECLARE @BettransDetail TABLE (
		RefNo			BIGINT,
		Odds			MONEY,
		Stake			MONEY,
		Status			NVARCHAR(10),
		APositionTaking	SMALLMONEY,
		MPositionTaking	SMALLMONEY,
		SPositionTaking	SMALLMONEY,
		BetType			SMALLINT,
		BetTeam			NVARCHAR(10),
		TransDesc		VARCHAR(1000)
	)

	--Use Local variables to avoid bad params sniffing
	DECLARE @_Date SMALLDATETIME

	SET @_Date = @Date

	-- bettrans
	IF @Date > @MoveBetsDay
	BEGIN
		INSERT INTO @Tickets (
			TransId,
			RefNo,
			WinLostDate,
			Product
		)
		SELECT
			b.transid,
			b.refno,
			b.winlostdate,
			CASE
				WHEN s.EventType = 0 AND s.ProductID = 1 THEN 'Parlay'		-- Sportsbook Parlay
				WHEN s.EventType = 1 AND s.ProductID = 1 THEN 'SB'			-- Sportsbook
				WHEN s.EventType = 2 AND s.ProductID = 1 THEN 'Outright'
				ELSE 'Unknown'
			END AS Product
		FROM dbo.bettrans AS b WITH (NOLOCK)
			INNER JOIN @SportBettype AS s ON b.bettype = s.bettype
		WHERE b.srecommend = @CustId
			AND b.winlostdate = @_Date
			AND b.ip = @Ip
			AND (s.SubProduct NOT IN ('MG-SuperLive') OR b.StatusId NOT IN (0, 1))

		DELETE FROM @Tickets WHERE Product = 'Unknown'

		IF EXISTS (SELECT 1 FROM @Tickets)
		BEGIN
			INSERT INTO @MemBetTicket
			SELECT
				TransId = CASE
								WHEN c.Product = 'Parlay' AND b.bettype = 29 AND ISNULL(b.betid, 0) > 0 THEN b.betid
								ELSE b.transid
							END,
				RefNo = b.refno,
				CustId = b.custid,
				Username = b.username,
				SportType = CASE
								WHEN c.Product IN ('SB') THEN m.sporttype
								WHEN c.Product IN ('Outright') THEN l.sporttype
								ELSE 0
							END,
				BetType = b.bettype,
				BetId = ISNULL(b.betid, 0),
				BetTeam = CASE
								WHEN c.Product IN ('SB', 'Parlay') THEN b.betteam
								ELSE ''
							END,
				Hdp1 = CASE
							WHEN c.Product IN ('SB', 'Parlay') THEN b.hdp1
							ELSE 0
						END,
				Hdp2 = CASE 
							WHEN c.Product IN ('SB', 'Parlay') THEN b.hdp2
							ELSE 0
						END,
				OddsType = CASE 
								WHEN c.Product IN ('SB') THEN b.oddstype
								ELSE 0
							END,
				Odds = b.odds,
				MOdds = b.modds,
				Stake = b.stake,
				Actual_Stake = b.actual_stake,
				Status = CASE
							WHEN c.Product = 'SB' AND b.bettype NOT IN (9, 29)
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
							ELSE b.status
						END,
				SettlementStatus = CASE
										WHEN c.Product IN ('SB') THEN ISNULL(m.SettlementStatus, 0)
										ELSE 0
									END,
				TransDate = b.transdate,
				WinLostDate = b.winlostdate,
				WinLost = b.winlost - b.actual_stake,
				AWinLost = b.awinlost,
				MWinLost = b.mwinlost,
				SWinLost = b.swinlost,
				PlayerComm = b.playercomm,
				Comm = b.comm - b.playercomm,
				AComm = b.acomm - b.comm,
				SComm = b.scomm - b.acomm,
				APositionTaking = b.apositiontaking,
				MPositionTaking = b.mpositiontaking,
				SPositionTaking = b.spositiontaking,
				TPositionTaking = b.tpositiontaking,
				ADiscount = b.discount,
				MDiscount = b.adiscount,
				SDiscount = b.sdiscount,
				LiveIndicator = CASE
									WHEN c.Product IN ('SB') THEN b.liveindicator
									ELSE 0
								END,
				LiveHomeScore = b.livehomescore,
				LiveAwayScore = b.liveawayscore,
				FinalHomeScore = CASE
									WHEN c.Product IN ('SB') THEN m.finalhomescore
									ELSE 0
								END,
				FinalAwayScore = CASE
									WHEN c.Product IN ('SB') THEN m.finalawayscore
									ELSE 0
								END,
				HtHomeScore = CASE
									WHEN c.Product IN ('SB') THEN m.hthomescore
									ELSE 0
								END,
				HtAwayScore = CASE
									WHEN c.Product IN ('SB') THEN m.htawayscore
									ELSE 0
								END,
				Ip = b.ip,
				LeagueId = CASE
								WHEN c.Product IN ('SB') THEN m.leagueid
								WHEN c.Product IN ('Outright') THEN o.leagueid
								ELSE 0
							END,
				MatchId = CASE
								WHEN c.Product IN ('SB') THEN m.matchid
								ELSE 0
							END,
				MatchCode = CASE
								WHEN c.Product IN ('SB') THEN m.matchcode
								ELSE ''
							END,
				EventDate = CASE
								WHEN c.Product = 'SB' THEN m.GlobalShowTime
								ELSE b.winlostdate
							END,
				HomeId = CASE
							WHEN c.Product IN ('SB') THEN m.homeid
							WHEN c.Product IN ('Outright') THEN o.teamid
							ELSE 0
						END,
				AwayId = CASE
							WHEN c.Product IN ('SB') THEN m.awayid
							ELSE 0
						END,
				BetStatus = CASE
								WHEN c.Product IN ('SB') THEN m.betstatus
								ELSE ''
							END,
				IsNeutral = CASE
								WHEN c.Product IN ('SB') THEN ISNULL(m.IsNeutral, 0)
								ELSE 0
							END,
				ShowTime = CASE
								WHEN c.Product IN ('SB') THEN ISNULL(m.showtime, '')
								ELSE ''
							END,
				BetCheck = CASE 
								WHEN c.Product IN ('SB', 'Parlay') THEN ISNULL(b.betcheck, '')
								ELSE '' 
							END,
				ComStatus = CASE WHEN b.comstatus = '1' THEN '1' ELSE '0' END,
				TransDesc = CASE
								WHEN c.Product IN ('SB') THEN ISNULL(b.transdesc, '')
								ELSE ''
							END,
				OddsSpread = CASE
								WHEN c.Product IN ('SB') THEN ISNULL(b.oddsspread, 0)
								ELSE 0
							END,
				ExtraInfo = CASE
								WHEN c.Product IN ('SB') THEN ISNULL(b.ExtraInfo, '')
								ELSE ''
							END,
				Currency = b.currencyname
			FROM @Tickets AS c
				INNER JOIN dbo.bettrans AS b WITH (NOLOCK) ON b.transid = c.transid
				LEFT JOIN dbo.match AS m WITH (NOLOCK) ON c.Product IN ('SB') AND b.matchid = m.matchid
				LEFT JOIN dbo.outright AS o WITH (NOLOCK) ON c.Product IN ('Outright') AND b.matchid = o.orid
				LEFT JOIN dbo.League AS l WITH (NOLOCK) ON c.Product IN ('Outright') AND o.leagueID = l.leagueID
		END

		DELETE FROM @Tickets

		-- translog
		INSERT INTO @Tickets (
			TransId,
			RefNo,
			WinLostDate,
			Product )
		SELECT
			b.translogid AS TransId,
			b.translogid AS RefNo,
			b.winlostdate,
			'MG' AS Product
		FROM dbo.translog AS b WITH (NOLOCK)
		WHERE b.srecommend = @CustId
			AND b.winlostdate = @_Date
			AND b.ip = @Ip
			AND b.statusID IN (0, 1)
			AND b.gameID BETWEEN 801 AND 899

		IF EXISTS (SELECT 1 FROM @Tickets)
		BEGIN
			INSERT INTO @MemBetTicket
			SELECT
				TransId = b.translogid,
				RefNo = b.translogid,
				CustId = b.custid,
				Username = b.username,
				SportType = m.sporttype,
				BetType = b.gameID,
				BetId = 0,
				BetTeam = '',
				Hdp1 = 0,
				Hdp2 = 0,
				OddsType = CONVERT(TINYINT, ISNULL(b.custom1, 0)),
				Odds = b.odds,
				MOdds = 0,
				Stake = b.stake,
				Actual_Stake = b.actual_stake,
				Status = b.status,
				SettlementStatus = 0,
				TransDate = b.transdate,
				WinLostDate = b.winlostdate,
				WinLost = 0,
				AWinLost = 0,
				MWinLost = 0,
				SWinLost = 0,
				PlayerComm = 0,
				Comm = 0,
				AComm = 0,
				SComm = 0,
				APositionTaking = b.APositiontaking,
				MPositionTaking = b.MPositiontaking,
				SPositionTaking = b.SPositiontaking,
				TPositionTaking = b.TPositiontaking,
				ADiscount = b.discount,
				MDiscount = b.adiscount,
				SDiscount = b.sdiscount,
				LiveIndicator = 0,
				LiveHomeScore = 0,
				LiveAwayScore = 0,
				FinalHomeScore = m.finalhomescore,
				FinalAwayScore = m.finalawayscore,
				HtHomeScore = m.hthomescore,
				HtAwayScore = m.htawayscore,
				Ip = b.ip,
				LeagueId = m.leagueid,
				MatchId = m.matchid,
				MatchCode = m.matchcode,
				EventDate = m.GlobalShowTime,
				HomeId = m.homeid,
				AwayId = m.awayid,
				BetStatus = m.betstatus,
				IsNeutral = ISNULL(m.IsNeutral, 0),
				ShowTime = ISNULL(m.showtime, ''),
				BetCheck = '',
				ComStatus = 0,
				TransDesc = b.transdesc,
				OddsSpread = 0,
				ExtraInfo = '',
				Currency = b.currencyname
			FROM @Tickets AS c
				INNER JOIN dbo.translog AS b WITH (NOLOCK) ON b.translogid = c.TransId
				INNER JOIN dbo.match AS m WITH (NOLOCK) ON b.eventid = m.matchid
		END
	END

	-- bettrans14
	IF @Date <= @MoveBetsDay
	BEGIN
		INSERT INTO @Tickets (
			TransId,
			RefNo,
			WinLostDate,
			Product
		)
		SELECT
			b.transid,
			b.refno,
			b.winlostdate,
			CASE
				WHEN s.EventType = 0 AND s.ProductID = 1 THEN 'Parlay'		-- Sportsbook Parlay
				WHEN s.EventType = 1 AND s.ProductID = 1 THEN 'SB'			-- Sportsbook
				WHEN s.EventType = 2 AND s.ProductID = 1 THEN 'Outright'
				ELSE 'Unknown'
			END AS Product
		FROM dbo.bettrans14 AS b WITH (NOLOCK)
			INNER JOIN @SportBettype AS s ON b.bettype = s.Bettype
		WHERE b.srecommend = @CustId
			AND b.winlostdate = @_Date
			AND b.ip = @Ip

		DELETE FROM @Tickets WHERE Product = 'Unknown'

		IF EXISTS (SELECT 1 FROM @Tickets)
		BEGIN
			INSERT INTO @MemBetTicket
			SELECT
				TransId = CASE
								WHEN c.Product = 'Parlay' AND b.bettype = 29 AND ISNULL(b.betid, 0) > 0 THEN b.betid
								ELSE b.transid
							END,
				RefNo = b.refno,
				CustId = b.custid,
				Username = b.username,
				SportType = CASE
								WHEN c.Product IN ('SB') THEN m.sporttype
								WHEN c.Product IN ('Outright') THEN l.sporttype
								ELSE 0
							END,
				BetType = b.bettype,
				BetId = ISNULL(b.betid, 0),
				BetTeam = CASE
								WHEN c.Product IN ('SB', 'Parlay') THEN b.betteam
								ELSE ''
							END,
				Hdp1 = CASE
							WHEN c.Product IN ('SB', 'Parlay') THEN b.hdp1
							ELSE 0
						END,
				Hdp2 = CASE
							WHEN c.Product IN ('SB', 'Parlay') THEN b.hdp2
							ELSE 0
						END,
				OddsType = CASE
								WHEN c.Product IN ('SB') THEN b.oddstype
								ELSE 0
							END,
				Odds = b.odds,
				MOdds = b.modds,
				Stake = b.stake,
				Actual_Stake = b.actual_stake,
				Status = b.status,
				SettlementStatus = 0,
				TransDate = b.transdate,
				WinLostDate = b.winlostdate,
				WinLost = b.winlost - b.actual_stake,
				AWinLost = b.awinlost,
				MWinLost = b.mwinlost,
				SWinLost = b.swinlost,
				PlayerComm = b.playercomm,
				Comm = b.comm - b.playercomm,
				AComm = b.acomm - b.comm,
				SComm = b.scomm - b.acomm,
				APositionTaking = b.apositiontaking,
				MPositionTaking = b.mpositiontaking,
				SPositionTaking = b.spositiontaking,
				TPositionTaking = b.tpositiontaking,
				ADiscount = b.discount,
				MDiscount = b.adiscount,
				SDiscount = b.sdiscount,
				LiveIndicator = CASE 
									WHEN c.Product IN ('SB') THEN b.liveindicator
									ELSE 0
								END,
				LiveHomeScore = b.livehomescore,
				LiveAwayScore = b.liveawayscore,
				FinalHomeScore = CASE
										WHEN c.Product IN ('SB') THEN m.finalhomescore
										ELSE 0
									END,
				FinalAwayScore = CASE
									WHEN c.Product IN ('SB') THEN m.finalawayscore
									ELSE 0
								END,
				HtHomeScore = CASE
									WHEN c.Product IN ('SB') THEN m.hthomescore
									ELSE 0
								END,
				HtAwayScore = CASE
									WHEN c.Product IN ('SB') THEN m.htawayscore
									ELSE 0
								END,
				Ip = b.ip,
				LeagueId = CASE
								WHEN c.Product IN ('SB') THEN m.leagueid
								WHEN c.Product IN ('Outright') THEN o.leagueid
								ELSE 0
							END,
				MatchId = CASE
								WHEN c.Product IN ('SB') THEN m.matchid
								ELSE 0
							END,
				MatchCode = CASE
								WHEN c.Product IN ('SB') THEN m.matchcode
								ELSE ''
							END,
				EventDate = CASE
								WHEN c.Product = 'SB' THEN m.globalshowtime
								ELSE b.winlostdate
							END,
				HomeId = CASE
								WHEN c.Product IN ('SB') THEN m.homeid
								WHEN c.Product IN ('Outright') THEN o.teamid
								ELSE 0
							END,
				AwayId = CASE
								WHEN c.Product IN ('SB') THEN m.awayid
								ELSE 0
							END,
				BetStatus = CASE
								WHEN c.Product IN ('SB') THEN m.betstatus
								ELSE ''
							END,
				IsNeutral = CASE
								WHEN c.Product IN ('SB') THEN ISNULL(m.IsNeutral, 0)
								ELSE 0
							END,
				ShowTime = CASE
								WHEN c.Product IN ('SB') THEN ISNULL(m.showtime, '')
								ELSE ''
							END,
				BetCheck = CASE 
								WHEN c.Product IN ('SB', 'Parlay') THEN ISNULL(b.betcheck, '')
								ELSE ''
							END,
				ComStatus = CASE WHEN b.comstatus = '1' THEN '1' ELSE '0' END,
				TransDesc = CASE
								WHEN c.Product IN ('SB') THEN ISNULL(b.transdesc, '')
								ELSE ''
							END,
				OddsSpread = CASE
								WHEN c.Product IN ('SB') THEN ISNULL(b.oddsspread, 0)
								ELSE 0
							END,
				ExtraInfo = CASE
								WHEN c.Product IN ('SB') THEN ISNULL(b.ExtraInfo, '')
								ELSE ''
							END,
				Currency = b.currencyname
			FROM @Tickets AS c
				INNER JOIN dbo.bettrans14 AS b WITH (NOLOCK) ON b.transid = c.transid
				LEFT JOIN dbo.match14 AS m WITH (NOLOCK) ON c.Product IN ('SB') AND b.matchid = m.matchid
				LEFT JOIN dbo.outright14 AS o WITH (NOLOCK) ON c.Product IN ('Outright') AND b.matchid = o.orid
				LEFT JOIN dbo.League AS l WITH (NOLOCK) ON c.Product IN ('Outright') AND o.leagueID = l.leagueID
		END
	END

	SELECT *
	FROM @MemBetTicket
	ORDER BY 1 DESC

	-- OUTPUT ticket detail
	SELECT *
	FROM @BettransDetail
	ORDER BY RefNo DESC
END
GO



GRANT EXECUTE ON [dbo].[Age_BetList_IPMatching] TO [bodbDownlineNet]
GO
GRANT EXECUTE ON [dbo].[Age_BetList_IPMatching] TO [bodbDownlineNetView]
GO
