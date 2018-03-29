USE bodb02
GO

ALTER PROCEDURE [dbo].[Acc_BetList_CheckBet]
	@RefNo BIGINT
AS

/*
	Created by: 20160510@Kos
	Task: NAP Report - Bet List of Check Bet report
	DB: DBACC.bodb02
	Original: Acc_BetsSelBetList_ByTransID_Advance
	
	Revisions:
		- 20160725@Kos: Use inline function for SportBettypeMatrix
		- 20160919@Kos: Exclude bet type 904 [#Redmine: 58978]
		- 20170301@Kos: Support KickOffTime for Virtual Soccer and Virtual Tennis [#Redmine: 71906]
		- 20170404@Kos: Support CashOut [#Redmine: 71963]
		- 20170623@Kos: Support Betradar Virtual Sports [#Redmine: 77280]
		- 20170831@Kos: Support Lucky 3 [#Redmine: 75277]
		- 20171101@Kos: Support Bullfighting [#Redmine: 85382]
					- Change param @TransId into @RefNo
					- Don't support Metric Gaming
		- 20180119@Kos: Add Match No for Bullfighting [#Redmine: 85382]
					- Move SP from DBAGE to DBACC
					- Don't support Racing anymore
		- 20180223@Kos: Support Licensee Bonus System [#Redmine: 74978]
		- 20180329@Kos: Increase TransDesc length to 1000 [#Redmine: 92842]
*/

BEGIN
	SET NOCOUNT ON

	-- Get Sport Bettype Matrix
	DECLARE @SportBetType TABLE(ProductID TINYINT, Bettype SMALLINT, EventType TINYINT, RefTable TINYINT)

	DECLARE @IsTest BIT = 0

	SELECT @IsTest = dbo.f_CheckSPVersion(@@PROCID)

	-- Support Sportsbook, Number Game, Virtual Sports, Lucky 3, Betradar Virtual Sports, Bullfighting only
	-- Don't support BetTrade, CashOut, Metric Gaming
	INSERT INTO @SportBetType
	SELECT ProductID, BetType, EventType, RefTable
	FROM dbo.f_SportBettypeMatrix_Sel (0, 0, 0, 2, '', '', @IsTest)
	WHERE ProductID IN (1, 3, 5, 26, 27, 30)
		AND BetType NOT BETWEEN 901 AND 920
		AND BetType NOT BETWEEN 801 AND 806

	DECLARE @Data TABLE (
		Username		NVARCHAR(50),
		BetType			INT,
		TransId			BIGINT,
		BetId			BIGINT,
		RefNo			BIGINT,
		MatchCode		NVARCHAR(50),
		Race			NVARCHAR(20),
		EventDate		SMALLDATETIME,
		VirtualRate		FLOAT,
		IsShowOTExRate	BIT,
		SDiscount		SMALLMONEY,
		ADiscount		SMALLMONEY,
		Discount		SMALLMONEY,
		HomeId			INT,
		AwayId			INT,
		SettleTime		DATETIME,
		Hdp1			SMALLMONEY,
		Hdp2			SMALLMONEY,
		Odds			MONEY,
		FinalOdds		MONEY,
		FinalOdds2		MONEY,
		OddsType		TINYINT,
		Status			NVARCHAR(50),
		ComStatus		NVARCHAR(50),
		Stake			MONEY,
		Actual_Stake	MONEY,
		TransDate		DATETIME,
		BetTeam			NVARCHAR(50),
		SPositionTaking SMALLMONEY,
		MPositionTaking SMALLMONEY,
		APositionTaking SMALLMONEY,
		SPositionTaking2 SMALLMONEY,
		MPositionTaking2 SMALLMONEY,
		APositionTaking2 SMALLMONEY,
		LiveIndicator	BIT,
		MOdds			MONEY,
		CustId			INT,
		LiveHomeScore	INT,
		LiveAwayScore	INT,
		FinalHomeScore	INT,
		FinalAwayScore	INT,
		LeagueId		INT,
		SportType		SMALLINT,
		Ip				NVARCHAR(15),
		BetFrom			NVARCHAR(1),
		MatchId			INT,
		IsNeutral		BIT,
		WinLost			MONEY,
		Commission		MONEY,
		SComm			MONEY,
		AComm			MONEY,
		Comm			MONEY,
		AWinLost		MONEY,
		MWinLost		MONEY,
		SWinLost		MONEY,
		ShowTime		NVARCHAR(50),
		WinLostDate		SMALLDATETIME,
		BetCheck		NVARCHAR(50),
		TransDesc		NVARCHAR(1000),
		OddsSpread		MONEY,
		BetdaqId		BIGINT,
		ExtraInfo		VARCHAR(1000),
		WalletType		TINYINT,
		RefCode			BIGINT
	)

	DECLARE
		@TransId	BIGINT,
		@ProductId	TINYINT,
		@BetType	SMALLINT,
		@EventType	TINYINT,
		@WhTicket	TINYINT	= 0

	-- Find ticket
	SELECT TOP(1)
		@TransId = b.translogid,
		@ProductId = s.ProductID,
		@BetType = b.gameID,
		@EventType = s.EventType,
		@WhTicket = 1		-- translog
	FROM dbo.translog AS b WITH (NOLOCK)
		INNER JOIN @SportBetType AS s ON b.gameID = s.Bettype
	WHERE b.translogid = @RefNo
		AND b.statusID IN (0, 1)
		AND s.RefTable = 3

	IF @WhTicket = 0
	BEGIN
		SELECT TOP(1)
			@TransId = b.transid,
			@ProductId = s.ProductID,
			@BetType = b.bettype,
			@EventType = s.EventType,
			@WhTicket = 2		-- bettrans
		FROM dbo.bettrans AS b WITH (NOLOCK)
			INNER JOIN @SportBetType AS s ON b.bettype = s.Bettype
		WHERE (b.transid = @RefNo AND s.RefTable <> 3)
			OR (b.refno = @RefNo
				AND s.RefTable = 3
				AND b.statusID NOT IN (0, 1))
	END

	-- Get ticket info
	IF @WhTicket = 1	-- translog
	BEGIN
		-- Bullfighting (EventType = 5)
		IF @EventType = 5
		BEGIN
			INSERT INTO @Data
			SELECT
				b.username,
				b.gameid AS BetType,
				b.translogid AS TransId,
				0 AS BetId,
				b.translogid AS RefNo,
				m.MatchNo AS MatchCode,
				'' AS Race,
				m.EventDate,
				0 AS VirtualRate,
				0 AS IsShowOTExRate,
				b.sdiscount,
				b.adiscount,
				b.discount,
				m.HomeId,
				m.AwayId,
				'' AS SettleTime,
				CASE
					WHEN @ProductId = 30 THEN CONVERT(SMALLMONEY, ISNULL(b.custom2, 0))
					ELSE 0
				END AS Hdp1,
				0 AS Hdp2,
				b.odds,
				0 AS FinalOdds,
				0 AS FinalOdds2,
				CASE
					WHEN @ProductId = 30 THEN CONVERT(TINYINT, ISNULL(b.custom1, 0))
					ELSE 0
				END AS OddsType,
				b.status,
				'' AS comstatus,
				b.stake,
				b.actual_stake,
				b.transdate,
				CASE
					WHEN @ProductId = 30 THEN ISNULL(b.custom3, '')
					ELSE ''
				END AS BetTeam,
				b.spositiontaking,
				b.mpositiontaking,
				b.apositiontaking,
				0 AS spositiontaking2,
				0 AS mpositiontaking2,
				0 AS apositiontaking2,
				b.liveindicator,
				0 AS MOdds,
				b.custid,
				0 AS LiveHomeScore,
				0 AS LiveAwayScore,
				0 AS FinalHomeScore,
				0 AS FinalAwayScore,
				m.League3rdId AS LeagueId,
				m.SportType,
				b.ip,
				b.betfrom,
				m.Match3rdId AS MatchId,
				0 AS IsNeutral,
				(-b.actual_stake) AS WinLost,
				0 AS commission,
				0 AS scomm,
				0 AS acomm,
				0 AS comm,
				0 AS AWinLost,
				0 AS MWinLost,
				0 AS SWinLost,
				'' AS ShowTime,
				b.winlostdate,
				CASE
					WHEN @ProductId = 30 THEN ISNULL(b.Tranid3rd, '')
					ELSE ''
				END AS BetCheck,
				CASE
					WHEN @ProductId = 30 THEN ISNULL(b.transdesc, '')
					ELSE ''
				END AS TransDesc,
				0 AS OddsSpread,
				-1 AS BetdaqId,
				'' AS ExtraInfo,
				0 AS WalletType,
				0 AS RefCode
			FROM dbo.translog AS b WITH (NOLOCK)
				INNER JOIN dbo.Match3rd AS m WITH (NOLOCK) ON b.eventid = m.Match3rdId
			WHERE b.translogid = @TransId
		END
	END
	
	IF @WhTicket = 2	-- bettrans
	BEGIN
		-- Sportsbook, Number Game, Virtual Sports, Lucky 3, Betradar Virtual Sports (EventType = 1)
		IF @EventType = 1
		BEGIN
			INSERT INTO @Data
			SELECT
				b.username,
				b.bettype,
				b.transid,
				ISNULL(b.betid, 0) AS BetID,
				b.refno,
				m.matchcode,
				'' AS Race,
				m.eventdate,
				0 AS virtualrate,
				0 AS isShowOTExRate,
				CASE
					WHEN @ProductId = 26 THEN 0
					ELSE b.sdiscount
				END AS SDiscount,
				CASE
					WHEN @ProductId = 26 THEN 0
					ELSE b.adiscount
				END AS ADiscount,
				CASE
					WHEN @ProductId = 26 THEN 0
					ELSE b.discount
				END AS Discount,
				m.homeid,
				m.awayid,
				ISNULL(b.checktime,'') settleTime,
				b.hdp1,
				b.hdp2,
				b.odds,
				0 AS FinalOdds,
				0 AS FinalOdds2,
				b.OddsType,
				CASE
					WHEN b.status = 'running' AND ISNULL(b.SecAcceptFlag, 0) = 1 AND ISNULL(b.checktime, CURRENT_TIMESTAMP) > CURRENT_TIMESTAMP THEN 'waiting'
					ELSE b.status 
				END AS status,
				CASE WHEN b.comstatus = '1' THEN 1 ELSE 0 END AS comstatus,
				b.stake,
				b.actual_stake,
				b.transdate,
				b.betteam,
				b.spositiontaking,
				b.mpositiontaking,
				b.apositiontaking,
				0 AS spositiontaking2,
				0 AS mpositiontaking2,
				0 AS apositiontaking2,
				b.liveindicator,
				b.modds,
				b.custid,
				b.livehomescore,
				b.liveawayscore,
				m.finalhomescore,
				m.finalawayscore,
				m.leagueid,
				m.sporttype,
				b.ip,
				b.betfrom,
				b.matchid,
				ISNULL(m.IsNeutral, CONVERT(BIT,0)) AS IsNeutral,
				(b.winlost - b.actual_stake) AS WinLost,
				b.playercomm AS commission,
				(b.scomm - b.acomm) AS scomm,
				(b.acomm - b.comm) AS acomm,
				(b.comm - b.playercomm) AS comm,
				b.awinlost,
				b.mwinlost,
				b.swinlost,
				CASE
					WHEN @ProductId IN (5, 27) THEN CONVERT(NVARCHAR(50), m.kickofftime)
					ELSE m.showtime
				END AS ShowTime,
				b.winlostdate,
				b.BetCheck,
				ISNULL(b.transdesc, '') AS transdesc,
				ISNULL(b.oddsspread, 0) AS OddsSpread,
				CASE
					WHEN @ProductId = 1 THEN ISNULL(b.betdaqid, -1)
					ELSE -1
				END AS BetdaqId,
				CASE
					WHEN @ProductId = 1 THEN ISNULL(b.ExtraInfo, '')
					ELSE ''
				END AS ExtraInfo,
				CASE
					WHEN @ProductId = 1 THEN ISNULL(b.WalletType, 0)
					ELSE 0
				END AS WalletType,
				CASE
					WHEN @ProductId = 1 THEN ISNULL(b.RefCode, 0)
					ELSE 0
				END AS RefCode
			FROM
				dbo.bettrans AS b WITH (NOLOCK) 
				INNER JOIN dbo.match AS m WITH (NOLOCK) ON b.matchid = m.matchid
			WHERE b.transid = @TransId
		END

		-- Mix Parlay, System Parlay (Sportsbook), Mix Parlay (Betradar Virtual Sports)
		IF @BetType IN (9, 29, 2799)
		BEGIN
			INSERT INTO @Data
			SELECT
				b.username,
				b.bettype,
				CASE
					WHEN b.bettype = 29 AND ISNULL(b.betid, 0) > 0 THEN b.betid
					ELSE b.transid
				END AS transid,
				ISNULL(b.betid, 0) AS BetId,
				b.refno,
				'' AS matchcode,
				'' AS Race,
				'' AS eventdate,
				0 AS virtualrate,
				0 AS isShowOTExRate,
				b.sdiscount,
				b.adiscount,
				b.discount,
				0 AS homeid,
				0 AS awayid,
				'' AS settleTime,
				b.hdp1,
				b.hdp2,
				b.odds,
				0 AS finalodds,
				0 AS finalodds2,
				0 AS OddsType,
				b.status,
				CASE WHEN b.comstatus = '1' THEN 1 ELSE 0 END AS comstatus,
				b.stake,
				b.actual_stake,
				b.transdate,
				b.betteam,
				b.spositiontaking,
				b.mpositiontaking,
				b.apositiontaking,
				0 spositiontaking2,
				0 mpositiontaking2,
				0 apositiontaking2,
				0 liveindicator,
				b.modds,
				b.custid,
				b.livehomescore,
				b.liveawayscore,
				0,
				0,
				0 AS leagueid,
				0 AS sporttype,
				b.ip,
				b.betfrom,
				0 matchid,
				CONVERT(BIT, 0) AS IsNeutral,
				(b.winlost - b.actual_stake) AS WinLost,
				b.playercomm AS commission,
				(b.scomm - b.acomm) AS scomm,
				(b.acomm - b.comm) AS acomm,
				(b.comm - b.playercomm) AS comm,
				b.awinlost,
				b.mwinlost,
				b.swinlost,
				'' AS showtime,
				b.winlostdate,
				ISNULL(b.betcheck, '') AS BetCheck,
				'' AS transdesc,
				0 AS OddsSpread,
				-1 AS BetdaqId,
				'' AS ExtraInfo,
				0 AS WalletType,
				0 AS RefCode
			FROM dbo.bettrans AS b WITH (NOLOCK)
			WHERE b.transid = @TransId
		END

		-- Outright
		IF @BetType = 10
		BEGIN
			INSERT INTO @Data
			SELECT 
				b.username,
				b.bettype,
				b.transid,
				ISNULL(b.betid, 0) AS BetID,
				b.refno,
				odds.matchcode,
				odds.groupmatch AS race,
				odds.eventdate,
				0 AS virtualrate,
				0 AS isShowOTExRate,
				b.sdiscount,
				b.adiscount,
				b.discount,
				0 AS homeid,
				odds.teamid AS awayid,
				'' AS settleTime,
				b.hdp1,
				b.hdp2,
				b.odds,
				0 AS finalodds,
				0 AS finalodds2,
				0 AS OddsType,
				b.status,
				CASE WHEN b.comstatus = '1' THEN 1 ELSE 0 END AS comstatus,
				b.stake,
				b.actual_stake,
				b.transdate,
				b.betteam,
				b.spositiontaking,
				b.mpositiontaking,
				b.apositiontaking,
				0 spositiontaking2,
				0 mpositiontaking2,
				0 apositiontaking2,
				b.liveindicator,
				b.modds,
				b.custid,
				b.livehomescore,
				b.liveawayscore,
				0,
				0,
				odds.leagueid,
				l.sporttype,
				b.ip,
				b.betfrom,
				b.matchid,
				CONVERT(BIT,0) AS IsNeutral,
				(b.winlost - b.actual_stake) AS WinLost,
				b.playercomm AS commission,
				(b.scomm - b.acomm) AS scomm,
				(b.acomm - b.comm) AS acomm,
				(b.comm - b.playercomm) AS comm,
				b.awinlost,
				b.mwinlost,
				b.swinlost,
				'' AS showtime,
				b.winlostdate,
				b.BetCheck,
				'' AS transdesc,
				0 AS OddsSpread,
				-1 AS BetdaqId,
				'' AS ExtraInfo,
				0 AS WalletType,
				0 AS RefCode
			FROM dbo.bettrans AS b WITH (NOLOCK)
				INNER JOIN dbo.outright AS odds WITH (NOLOCK) ON b.matchid = odds.orid
				INNER JOIN dbo.league AS l WITH (NOLOCK) ON odds.leagueid = l.leagueid
			WHERE b.transid = @TransId
		END

		-- Virtual Horse Racing (EventType = 3)
		IF @EventType = 3
		BEGIN
			INSERT INTO @Data
			SELECT
				b.username,
				b.bettype,
				b.transid,
				'' AS BetID,
				b.refno,
				o.RacerNum AS matchcode,
				b.oddsid AS Race,
				'' AS eventdate,
				0 AS virtualrate,
				0 AS isShowOTExRate,
				b.sdiscount,
				b.adiscount,
				b.discount,
				o.RacerID AS homeID,
				0 AS awayID,
				'' settleTime,
				b.hdp1,
				b.hdp2,
				b.odds,
				0 AS FinalOdds,
				0 AS FinalOdds2,
				b.OddsType,
				b.status,
				CASE WHEN b.comstatus = '1' THEN 1 ELSE 0 END AS comstatus,
				b.stake,
				b.actual_stake,
				b.transdate,
				'' betteam,
				CASE WHEN b.bettype = 1233 THEN bm.spositiontaking ELSE b.spositiontaking END,
				CASE WHEN b.bettype = 1233 THEN bm.mpositiontaking ELSE b.mpositiontaking END,
				CASE WHEN b.bettype = 1233 THEN bm.apositiontaking ELSE b.apositiontaking END,
				CASE WHEN b.bettype = 1233 THEN bm.spositiontaking2 ELSE 0 END,
				CASE WHEN b.bettype = 1233 THEN bm.mpositiontaking2 ELSE 0 END,
				CASE WHEN b.bettype = 1233 THEN bm.apositiontaking2 ELSE 0 END,
				0 AS LiveIndicator,
				b.modds,
				b.custid,
				b.livehomescore,
				b.liveawayscore,
				0 finalhomescore,
				0 finalawayscore,
				r.leagueid,
				r.sporttype,
				b.ip,
				b.betfrom,
				b.matchid,
				CONVERT(BIT, 0) AS IsNeutral,
				(b.winlost - b.actual_stake) AS WinLost,
				b.playercomm AS commission,
				(b.scomm - b.acomm) AS scomm,
				(b.acomm - b.comm) AS acomm,
				(b.comm - b.playercomm) AS comm,
				b.awinlost,
				b.mwinlost,
				b.swinlost,
				r.EventTime AS showtime,
				b.winlostdate,
				b.BetCheck,
				'' AS transdesc,
				0 AS OddsSpread,
				-1 AS BetdaqId,
				'' AS ExtraInfo,
				0 AS WalletType,
				0 AS RefCode
			FROM dbo.bettrans AS b WITH (NOLOCK)
				INNER JOIN dbo.VSOutright AS o WITH (NOLOCK) ON b.oddsid = o.Orid
				INNER JOIN dbo.VSRaceInfo AS r WITH (NOLOCK) ON r.EventID = o.EventID
				INNER JOIN @SportBetType AS s ON s.BetType = b.BetType
				LEFT JOIN (
					SELECT
						t.refno,
						t.apositiontaking,
						t.mpositiontaking,
						t.spositiontaking,
						f.apositiontaking AS apositiontaking2,
						f.mpositiontaking AS mpositiontaking2,
						f.spositiontaking AS spositiontaking2
					FROM dbo.bettransm AS t WITH (NOLOCK)
						INNER JOIN dbo.bettransm AS f WITH (NOLOCK) ON t.refno = f.refno
					WHERE t.bettype = 1231 AND f.bettype = 1232
					) bm ON b.refno = bm.refno
			WHERE b.transid = @TransId
		END

		-- Bullfighting (EventType = 5)
		IF @EventType = 5
		BEGIN
			INSERT INTO @Data
			SELECT
				b.username,
				b.bettype,
				b.transid,
				ISNULL(b.betid, 0) AS BetID,
				b.refno,
				m.MatchNo AS MatchCode,
				'' AS Race,
				m.EventDate,
				0 AS VirtualRate,
				0 AS IsShowOTExRate,
				b.sdiscount,
				b.adiscount,
				b.discount,
				m.HomeId,
				m.AwayId,
				'' AS SettleTime,
				b.hdp1,
				0 AS Hdp2,
				b.odds,
				0 AS FinalOdds,
				0 AS FinalOdds2,
				b.OddsType,
				b.status,
				0 AS comstatus,
				b.stake,
				b.actual_stake,
				b.transdate,
				b.betteam,
				b.spositiontaking,
				b.mpositiontaking,
				b.apositiontaking,
				0 AS spositiontaking2,
				0 AS mpositiontaking2,
				0 AS apositiontaking2,
				b.liveindicator,
				0 AS MOdds,
				b.custid,
				0 AS LiveHomeScore,
				0 AS LiveAwayScore,
				0 AS FinalHomeScore,
				0 AS FinalAwayScore,
				m.League3rdId AS LeagueId,
				m.SportType,
				b.ip,
				b.betfrom,
				m.Match3rdId AS MatchId,
				0 AS IsNeutral,
				(b.winlost - b.actual_stake) AS WinLost,
				b.playercomm AS commission,
				(b.scomm - b.acomm) AS scomm,
				(b.acomm - b.comm) AS acomm,
				(b.comm - b.playercomm) AS comm,
				b.awinlost,
				b.mwinlost,
				b.swinlost,
				'' AS ShowTime,
				b.winlostdate,
				ISNULL(b.betcheck, '') AS BetCheck,
				ISNULL(b.transdesc, '') AS TransDesc,
				0 AS OddsSpread,
				-1 AS BetdaqId,
				'' AS ExtraInfo,
				0 AS WalletType,
				0 AS RefCode
			FROM
				dbo.bettrans AS b WITH (NOLOCK)
				INNER JOIN dbo.Match3rd AS m WITH (NOLOCK) ON b.matchid = m.Match3rdId
				INNER JOIN @SportBetType AS s ON s.Bettype = b.bettype
			WHERE
				s.EventType = 5
				AND b.transid = @TransId
				AND b.statusID NOT IN (0, 1)
		END
	END

	-- Don't display Cash text for ticket from Cash Wallet only
	UPDATE @Data
	SET WalletType = 0
	WHERE WalletType = 2 AND RefCode = 0

	-- Display Cash/Bonus text for ticket from multiple wallets
	UPDATE @Data
	SET RefCode = 0
	WHERE RefCode <> 0

	SELECT b.*,
		ex.currency
	FROM @Data AS b
		LEFT JOIN dbo.custInfo AS ci WITH (NOLOCK) ON b.CustId = ci.custid
		LEFT JOIN dbo.Exchange AS ex WITH (NOLOCK) ON ci.currency = ex.exchangeid
END




GO
GRANT EXECUTE ON [dbo].[Acc_BetList_CheckBet] TO [bodbAdminNet]
GO
GRANT EXECUTE ON [dbo].[Acc_BetList_CheckBet] TO [bodbExtAccNet]
GO
GRANT VIEW DEFINITION ON [dbo].[Acc_BetList_CheckBet] TO [vnteam]
GO
