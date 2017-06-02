USE bodb02
GO

ALTER PROCEDURE [dbo].[Acc_BetListByIP_Soccer]
	@CustId		INT,
	@Ip			VARCHAR(15),
	@FromDate	DATETIME
AS
/*
	Created: Phuong Dao
	Task: Bet List By IP and Soccer
	DB: DBACC.bodb02 
	Original:Acc_BetListByDayAllIP

	Revisions:
		- 20090514@Simon: Remove RefNo
		- 20091002@Simon: Get Odds && OddsType columns
		- 20091003@Jamie: Remove comstatus out
		- 20091009@Daniel: Get refund status from bettrans
		- 20091205@Henry: Get more column: refno for viewing Mix Parlay detail
		- 20101205@Daniel: Fix swap column transid & refno due to diff column order between select statements
		- 20100611@Henry: Change mix-parlay match from 0 to 9
		- 20101201@Henry: Return winlost-actual_stake for column winlost
		- 20110408@Amy: Change function to get Odds value and odds type
		- 20110516@Lukas: re-arrange bettype
		- 20110802@Johnson: - Add column actual_stake into betlist
							- Add new bettype combination mix-parlay
		- 20111122@Sophia: Add Checktime and SecAcceptFlag to show status waiting or running
		- 20120120@Sophia: Add Showtime for Table-hand-shoe of Live Casino
						   Add sub detail for Live Casino
		- 20120426@Lukas: Show transid of mainticket for sub-tickets of system parlay
		- 20120606@Sophia: Change datatype of stake to money
		- 20120626@Elodie: exclude outright from sportbook ( in case of matchid = orid)
		- 20120629@Sophia: Remove function f_GetOddsByBettype, f_ShowOddsByBettype,f_GetChoice for odds, Oddstype, betteam
		- 20120927@Johnson: get commstatus column to check double comm losing
		- 20130718@Elodie: Apply core betlist
		- 20150415@Sophia: Get Betcheck for Betradar
		- 20150506@Bobby: Add transdesc column for metric gaming bettypes (801-899)
		- 20150615@Edward: Support for BetTrade
		- 20150707@Bobby: Exclude Metric Gaming running ticket from bettrans table
		- 20150826@Kos: Add OddsSpread column to support Myanmar Odds
		- 20151210@Kos: Change odds, modds data type from SMALLMONEY to MONEY [Redmine: #48660]
		- 20160119@Kos: Support PH All In One 1.2 [#Redmine: 50897]
		- 20160407@Kos: Support Combo Parlay [#Redmine: 55282]
		- 20160804@Kos: Exclude bet type 904 [#Redmine: 58978]
		- 20170321@Kos: Support CashOut [#Redmine: 71963]
		- 20170602@Kos: Get liveindicator from original ticket for 911 and 912 tickets [#Redmine: 77669]
	
	Param's Explanation:
		• @fromdate = @winlostdate
*/

BEGIN
	SET NOCOUNT ON

	DECLARE @Data TABLE (
		FinalHomeScore	INT,
		FinalAwayScore	INT,
		OddsId			INT,
		LeagueId		INT,
		MatchId			INT,
		BetType			SMALLINT,
		TransId			BIGINT,
		BetId			BIGINT,
		RefNo			BIGINT,
		MatchCode		NVARCHAR(50),
		Race			NVARCHAR(50),
		EventDate		DATETIME,
		VirtualRate		FLOAT,
		IsShowOTExRate	BIT,
		SDiscount		DECIMAL(9, 8),
		ADiscount		DECIMAL(9, 8),
		Discount		DECIMAL(9, 8),
		HomeId			INT,
		AwayId			INT,
		SettleTime		DATETIME,
		Hdp1			SMALLMONEY,
		Hdp2			SMALLMONEY,
		Odds			MONEY,
		FinalOdds		MONEY,
		FinalOdds2		MONEY,
		MOdds			MONEY,
		OddsType		INT, 
		Status			NVARCHAR(50),
		ComStatus		NVARCHAR(20),
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
		LiveHomeScore	INT,
		LiveAwayScore	INT,
		LiveIndicator	BIT,
		WinLost			MONEY,
		Commission		MONEY,
		SComm			MONEY,
		AComm			MONEY,
		Comm			MONEY,
		AWinLost		MONEY,
		MWinLost		MONEY,
		SWinLost		MONEY,
		Creator			VARCHAR(50),
		Username		NVARCHAR(50),
		HtHomeScore		INT,
		HtAwayScore		INT,
		Ip				NVARCHAR(15),
		BetFrom			NVARCHAR(1),
		SportType		INT,
		IsNeutral		BIT,
		ShowTime		NVARCHAR(50),
		WinLostDate		SMALLDATETIME,
		BetCheck		NVARCHAR(50),
		TransDesc		NVARCHAR(300),
		OddsSpread		SMALLMONEY,
		OriginalBetType	INT,
		BetdaqId		BIGINT,
		ExtraInfo		VARCHAR(1000)
	)

	DECLARE @DetailData TABLE (
		RefNo			NVARCHAR(50),
		Odds			MONEY,
		Stake			MONEY,
		Status			NVARCHAR(50),
		APositionTaking	SMALLMONEY,
		MPositionTaking	SMALLMONEY,
		SPositionTaking	SMALLMONEY,
		BetType			SMALLINT,
		BetTeam			NVARCHAR(50)
	)

	DECLARE @Date DATETIME

	SET @Date = @FromDate

	INSERT INTO @Data
	SELECT
		finalhomescore,
		finalawayscore,
		oddsid,
		leagueid,
		matchid,
		bettype,
		transid,
		betid,
		refno,
		matchcode,
		race,
		eventdate,
		virtualrate,
		isShowOTExRate,
		sdiscount,
		adiscount,
		discount,
		homeid,
		awayid,
		checkTime settleTime,
		hdp1,
		hdp2,
		odds,
		finalodds,
		finalodds2,
		modds,
		OddsType,
		status,
		comstatus,
		stake,
		actual_stake,
		transdate,
		betteam,
		spositiontaking, 
		mpositiontaking, 
		apositiontaking, 
		spositiontaking2,
		mpositiontaking2,
		apositiontaking2,
		livehomescore,
		liveawayscore,
		liveindicator,
		winlost,
		commission,
		scomm,
		acomm,
		comm,
		awinlost,
		mwinlost,
		swinlost,
		creator,
		username,
		hthomescore,
		htawayscore,
		ip,
		betfrom,
		sporttype,
		IsNeutral,
		showtime,
		winlostdate,
		BetCheck,
		transdesc,
		OddsSpread,
		OriginalBetType,
		BetdaqId,
		ExtraInfo
	FROM (
			SELECT
				m.finalhomescore,
				m.finalawayscore,
				b.oddsid,
				m.leagueid,
				b.bettype,
				b.transid,
				b.betid,
				b.refno,
				m.matchcode,
				'' AS race,
				'' AS eventdate,
				b.sdiscount,
				b.adiscount,
				b.discount,
				m.homeid,
				m.awayid,
				ISNULL(b.checktime,'') checktime,
				b.hdp1,
				b.hdp2,
				b.odds,
				b.modds,
				b.oddstype,
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
				b.livehomescore,
				b.liveawayscore,
				b.liveindicator,
				(b.winlost-b.actual_stake) AS winlost,
				b.playercomm AS commission,
				(b.scomm - b.acomm) AS scomm,
				(b.acomm - b.comm) AS acomm,
				(b.comm - b.playercomm) AS comm,
				b.awinlost,
				b.mwinlost,
				b.swinlost,
				c.username creator,
				b.username,
				m.hthomescore, 
				m.htawayscore,
				b.ip,
				b.betfrom,
				m.sporttype,
				b.matchid,
				m.IsNeutral,
				m.showtime,
				0 AS virtualrate,
				0 AS isShowOTExRate,
				0 finalodds,
				0 finalodds2,
				b.winlostdate,
				b.betcheck,
				ISNULL(b.transdesc, '') AS transdesc,
				ISNULL(b.oddsspread, 0) AS OddsSpread,
				0 AS OriginalBetType,
				ISNULL(b.betdaqid, -1) AS BetdaqId,
				ISNULL(b.ExtraInfo, '') AS ExtraInfo
			FROM dbo.bettrans14 AS b WITH (NOLOCK)
				INNER JOIN dbo.match14 AS m WITH (NOLOCK) ON b.matchid = m.matchid
				INNER JOIN dbo.custInfo AS c WITH (NOLOCK) ON c.custid = b.creator
			WHERE b.winlostdate = @Date
				AND b.bettype < 19001
				AND b.bettype NOT IN (10, 904, 914)	--20120626@Elodie: exclude outright from sportbook
				AND b.custid = @CustId
				AND m.sporttype = 1

			UNION ALL
			SELECT
				0 finalhomescore,
				0 finalawayscore,
				0,
				0 leagueid,
				9 bettype,
				b.transid,
				b.betid,
				b.refno,
				'' matchcode,
				'' race,
				'' AS eventdate,
				b.sdiscount,
				b.adiscount,
				b.discount,
				0 homeid, 
				0 awayid,
				ISNULL(b.checktime,'') checktime,
				0 hdp1,
				0 hdp2,
				b.odds,
				b.modds,
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
				0 livehomescore,
				0 liveawayscore,
				0 liveindicator,
				(b.winlost-b.actual_stake)  winlost,
				b.playercomm AS commission,
				(b.scomm - b.acomm) AS scomm,
				(b.acomm - b.comm) AS acomm,
				(b.comm - b.playercomm) AS comm,
				b.awinlost,
				b.mwinlost,
				b.swinlost,
				c.username creator,
				b.username,
				0 hthomescore, 
				0 htawayscore,
				b.ip,
				b.betfrom,
				0 sporttype,
				0 matchid,
				0 IsNeutral,
				'' AS showtime,
				0 AS virtualrate,
				0 AS isShowOTExRate,
				0 finalodds,
				0 finalodds2,
				b.winlostdate,
				b.BetCheck,
				'' AS transdesc,
				0 AS OddsSpread,
				0 AS OriginalBetType,
				-1 AS BetdaqId,
				'' AS ExtraInfo
			FROM dbo.bettrans14 AS b WITH (NOLOCK) 
				INNER JOIN dbo.custInfo AS c WITH (NOLOCK) ON c.custid = b.creator
			WHERE b.bettype = 9
				AND b.winlostdate = @Date
				AND b.matchid = 9
				AND b.custid = @CustId
				AND b.refno IN (SELECT RefNo
								FROM dbo.bettransm14 AS bm WITH (NOLOCK)
									INNER JOIN dbo.match14 AS m WITH (NOLOCK) ON bm.matchid = m.MatchID
								WHERE m.sporttype = 1)
			UNION ALL
			SELECT
				0 finalhomescore,
				0 finalawayscore,
				0,
				0 leagueid,
				29 bettype,
				CASE WHEN ISNULL(b.betID,0) = 0 THEN b.transid ELSE b.betID END AS transid,
				b.betid,
				b.refno,
				'' matchcode,
				'' race, 
				'' AS eventdate,
				b.sdiscount,
				b.adiscount,
				b.discount,
				0 homeid, 
				0 awayid,
				ISNULL(b.checktime,'') checktime,
				b.hdp1,
				b.hdp2,
				b.odds,
				b.modds,
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
				0 livehomescore, 
				0 liveawayscore,
				0 liveindicator,
				(b.winlost-b.actual_stake) AS winlost,
				b.playercomm AS commission,
				(b.scomm - b.acomm) AS scomm,
				(b.acomm - b.comm) AS acomm,
				(b.comm - b.playercomm) AS comm,
				b.awinlost,
				b.mwinlost,
				b.swinlost,
				c.username creator,
				b.username,
				0 hthomescore,
				0 htawayscore,
				b.ip,
				b.betfrom,
				0 sporttype,
				0 matchid,
				0 IsNeutral,
				'' AS showtime,
				0 AS virtualrate,
				0 AS isShowOTExRate,
				0 finalodds,
				0 finalodds2,
				b.winlostdate,
				ISNULL(b.betcheck, '') AS BetCheck,
				'' AS transdesc,
				0 AS OddsSpread,
				0 AS OriginalBetType,
				-1 AS BetdaqId,
				'' AS ExtraInfo
			FROM dbo.bettrans14 AS b WITH (NOLOCK)
				INNER JOIN dbo.custInfo AS c WITH (NOLOCK) ON c.custid = b.creator
			WHERE b.bettype = 29
				AND b.winlostdate = @Date
				AND b.matchid = 29
				AND b.custid = @CustId
				AND b.refno IN (	SELECT RefNo
									FROM dbo.bettransm14 AS bm WITH (NOLOCK)
										INNER JOIN dbo.match14 AS m WITH (NOLOCK) ON bm.matchid = m.MatchID
									WHERE m.sporttype = 1)

			UNION ALL
			----------------------------------------------------------------------------
			SELECT
				m.finalhomescore,
				m.finalawayscore,
				b.oddsid,
				m.leagueid,
				b.bettype,
				b.transid,
				b.betid,
				b.refno,
				m.matchcode,
				'' race,
				'' AS eventdate,
				b.sdiscount,
				b.adiscount,
				b.discount,
				m.homeid,
				m.awayid,
				ISNULL(b.checktime,'') checktime,
				b.hdp1,
				b.hdp2,
				b.odds,
				b.modds,
				b.oddstype,
				CASE WHEN b.status = 'running' AND ISNULL(b.SecAcceptFlag, 0) = 1 AND ISNULL(b.checktime, CURRENT_TIMESTAMP) > CURRENT_TIMESTAMP THEN 'waiting'
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
				0 spositiontaking2,
				0 mpositiontaking2,
				0 apositiontaking2,
				b.livehomescore,
				b.liveawayscore,
				b.liveindicator,
				(b.winlost-b.actual_stake) AS winlost,
				b.playercomm AS commission,
				(b.scomm - b.acomm) AS scomm,
				(b.acomm - b.comm) AS acomm,
				(b.comm - b.playercomm) AS comm,
				b.awinlost,
				b.mwinlost,
				b.swinlost,
				c.username creator,
				b.username,
				m.hthomescore, 
				m.htawayscore,
				b.ip,
				b.betfrom,
				m.sporttype,
				b.matchid,
				m.IsNeutral,
				m.showtime,
				0 AS virtualrate,
				0 AS isShowOTExRate,
				0 finalodds,
				0 finalodds2,
				b.winlostdate,
				b.BetCheck,
				ISNULL(b.transdesc, '') AS transdesc,
				ISNULL(b.oddsspread, 0) AS OddsSpread,
				0 AS OriginalBetType,
				ISNULL(b.betdaqid, -1) AS BetdaqId,
				ISNULL(b.ExtraInfo, '') AS ExtraInfo
			FROM dbo.bettrans AS b WITH (NOLOCK) 
				INNER JOIN dbo.match AS m WITH (NOLOCK) ON b.matchid = m.matchid
				INNER JOIN dbo.custInfo AS c WITH (NOLOCK) ON c.custid = b.creator
			WHERE b.winlostdate = @Date
				AND b.bettype < 19001
				AND b.bettype NOT IN (10, 904)	--20120626@Elodie: exclude outright from sportbook
				AND b.custid = @CustId
				AND m.sporttype = 1
				--exclude metric gaming running ticket
				AND (b.bettype NOT BETWEEN 801 AND 806
					OR (b.bettype BETWEEN 801 AND 806 AND b.statusID NOT IN (0, 1)))

			-- Metric gaming running ticket
			UNION ALL 
			SELECT 
				m.finalhomescore,
				m.finalawayscore,
				0 AS oddsid,
				m.leagueid,
				b.gameID AS bettype,
				b.translogid AS transid,
				0 AS betid,
				b.translogid AS refno,
				m.matchcode,
				'' race,
				'' AS eventdate,
				b.sdiscount,
				b.adiscount,
				b.discount,
				m.homeid,
				m.awayid,
				'' AS checktime,
				0 AS hdp1,
				0 AS hdp2,
				b.odds,
				0 AS modds,
				CASE
					WHEN b.gameid IN (801,803,804,805,806) THEN CONVERT(TINYINT, ISNULL(b.custom1, 0))
					ELSE 0
				END AS OddsType,
				b.status,
				0 AS comstatus,
				b.stake,
				b.actual_stake,
				b.transdate,
				'' AS betteam,
				b.spositiontaking,
				b.mpositiontaking,
				b.apositiontaking,
				0 AS spositiontaking2,
				0 AS mpositiontaking2,
				0 AS apositiontaking2,
				0 AS livehomescore,
				0 AS liveawayscore,
				0 AS liveindicator,
				0 AS winlost,
				0 AS commission,
				0 AS scomm,
				0 AS acomm,
				0 AS comm,
				0 AS awinlost,
				0 AS mwinlost,
				0 AS swinlost,
				c.username creator,
				b.username,
				m.hthomescore, 
				m.htawayscore,
				b.ip,
				b.betfrom,
				m.sporttype,
				b.eventID,
				m.IsNeutral,
				m.showtime,
				0 AS virtualrate,
				0 AS isShowOTExRate,
				0 finalodds,
				0 finalodds2,
				b.winlostdate,
				'' AS BetCheck,
				b.transdesc,
				0 AS OddsSpread,
				0 AS OriginalBetType,
				-1 AS BetdaqId,
				'' AS ExtraInfo
			FROM dbo.translog AS b WITH (NOLOCK)
				INNER JOIN dbo.match AS m WITH (NOLOCK) ON b.eventid = m.matchid
				INNER JOIN dbo.custInfo AS c WITH (NOLOCK) ON c.custid = b.creator
			WHERE b.winlostdate = @Date
				AND b.Gameid BETWEEN 801 AND 899
				AND b.custid = @CustId 
				AND b.statusID = 0
			
			-- Mix Parlay
			UNION ALL
			SELECT
				0 finalhomescore,
				0 finalawayscore,
				0,
				0 leagueid,
				9 bettype,
				b.transid,
				b.betid,
				b.refno,
				'' matchcode,
				'' race,
				'' AS eventdate,
				b.sdiscount,
				b.adiscount,
				b.discount,
				0 homeid,
				0 awayid,
				ISNULL(b.checktime,'') checktime,
				0 hdp1,
				0 hdp2,
				b.odds,
				b.modds,
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
				0 livehomescore, 
				0 liveawayscore,
				0 liveindicator,
				(b.winlost-b.actual_stake)  winlost,
				b.playercomm AS commission, 
				(b.scomm - b.acomm) AS scomm,
				(b.acomm - b.comm) AS acomm,
				(b.comm - b.playercomm) AS comm,
				b.awinlost,
				b.mwinlost,
				b.swinlost,
				c.username creator,
				b.username,
				0 hthomescore,
				0 htawayscore,
				b.ip,
				b.betfrom,
				0 sporttype,
				b.matchid,
				0 IsNeutral,
				'' AS showtime,
				0 AS virtualrate,
				0 AS isShowOTExRate,
				0 finalodds,
				0 finalodds2,
				b.winlostdate,
				b.BetCheck,
				'' AS transdesc,
				0 AS OddsSpread,
				0 AS OriginalBetType,
				-1 AS BetdaqId,
				'' AS ExtraInfo
			FROM dbo.bettrans AS b WITH (NOLOCK)
				INNER JOIN dbo.custInfo AS c WITH (NOLOCK) ON c.custid = b.creator
			WHERE b.winlostdate = @Date
				AND b.matchid = 9
				AND b.bettype = 9
				AND b.custid = @CustId
				AND b.refno IN (SELECT RefNo
								FROM dbo.bettransm AS bm WITH (NOLOCK)
									INNER JOIN dbo.match AS m WITH (NOLOCK) ON bm.matchid = m.matchid
								WHERE m.sporttype = 1 )

			UNION ALL
			SELECT 
				0 finalhomescore,
				0 finalawayscore,
				0,
				0 leagueid,
				29 bettype,
				CASE WHEN ISNULL(b.betID,0) = 0 THEN b.transid ELSE b.betID END AS transid,
				b.betid,
				b.refno,
				'' matchcode,
				'' race, 
				'' AS eventdate,
				b.sdiscount,
				b.adiscount,
				b.discount,
				0 homeid,
				0 awayid,
				ISNULL(b.checktime,'') checktime,
				b.hdp1,
				b.hdp2,
				b.odds,
				b.modds,
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
				0 livehomescore,
				0 liveawayscore,
				0 liveindicator,
				(b.winlost-b.actual_stake) AS winlost,
				b.playercomm AS commission,
				(b.scomm - b.acomm) AS scomm,
				(b.acomm - b.comm) AS acomm,
				(b.comm - b.playercomm) AS comm,
				b.awinlost,
				b.mwinlost,
				b.swinlost,
				c.username creator,
				b.username,
				0 hthomescore,
				0 htawayscore,
				b.ip,
				b.betfrom,
				0 sporttype,
				0 matchid,
				0 IsNeutral,
				'' AS showtime,
				0 AS virtualrate,
				0 AS isShowOTExRate,
				0 finalodds,
				0 finalodds2,
				b.winlostdate,
				ISNULL(b.betcheck, '') AS BetCheck,
				'' AS transdesc,
				0 AS OddsSpread,
				0 AS OriginalBetType,
				-1 AS BetdaqId,
				'' AS ExtraInfo
			FROM dbo.bettrans AS b WITH (NOLOCK) 
				INNER JOIN dbo.custInfo AS c WITH (NOLOCK) ON c.custid = b.creator
			WHERE b.winlostdate = @Date
				AND b.matchid = 29
				AND b.bettype = 29
				AND b.custid = @CustId
				AND b.refno IN (SELECT RefNo
								FROM dbo.bettransm AS bm WITH (NOLOCK)
									INNER JOIN dbo.match AS m WITH (NOLOCK) ON bm.matchid = m.matchid
								WHERE m.sporttype = 1 )

			-- Outright
			UNION ALL
			SELECT
				0 finalhomescore,
				0 finalawayscore,
				0 oddsid,
				odds.leagueid,
				b.bettype,
				b.transid,
				b.betid,
				b.refno,
				odds.matchcode,
				odds.groupmatch AS race,
				odds.eventdate,
				b.sdiscount,
				b.adiscount,
				b.discount,
				0 homeid,
				odds.teamid awayid,
				ISNULL(b.checktime,'') checktime,
				b.hdp1,
				b.hdp2,
				b.odds,
				b.modds,
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
				b.livehomescore,
				b.liveawayscore,
				0 liveindicator,
				(b.winlost-b.actual_stake)  winlost,
				b.playercomm AS commission,
				(b.scomm - b.acomm) AS scomm,
				(b.acomm - b.comm) AS acomm,
				(b.comm - b.playercomm) AS comm,
				b.awinlost,
				b.mwinlost,
				b.swinlost,
				CASE b.custid WHEN b.creator THEN b.Username ELSE '' END creator,
				b.username,
				0 hthomescore,
				0 htawayscore,
				b.ip,
				b.betfrom,
				l.sporttype,
				b.matchid,
				0 IsNeutral,
				'' AS showtime,
				0 AS virtualrate,
				0 AS isShowOTExRate,
				0 finalodds,
				0 finalodds2,
				b.winlostdate,
				b.BetCheck,
				'' AS transdesc,
				0 AS OddsSpread,
				0 AS OriginalBetType,
				-1 AS BetdaqId,
				'' AS ExtraInfo
			FROM dbo.bettrans AS b WITH (NOLOCK)
				INNER JOIN dbo.outright AS odds WITH (NOLOCK) ON b.matchid = odds.orid
				INNER JOIN dbo.league AS l WITH (NOLOCK) ON odds.leagueid = l.leagueid
			WHERE b.bettype = 10 
				AND b.winlostdate = @Date
				AND b.custid = @CustId
				AND l.sporttype = 1

			-- Outright 14
			UNION ALL
			SELECT
				0 finalhomescore,
				0 finalawayscore,
				0 oddsid,
				odds.leagueid,
				b.bettype,
				b.transid,
				b.betid,
				b.refno,
				odds.matchcode, 
				odds.groupmatch AS race,
				odds.eventdate AS eventdate,
				b.sdiscount,
				b.adiscount,
				b.discount,
				0 homeid,
				odds.teamid awayid,
				ISNULL(b.checktime,'') checktime,
				b.hdp1,
				b.hdp2,
				b.odds,
				b.modds,
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
				b.livehomescore,
				b.liveawayscore,
				0 liveindicator,
				(b.winlost-b.actual_stake)  winlost,
				b.playercomm AS commission,
				(b.scomm - b.acomm) AS scomm,
				(b.acomm - b.comm) AS acomm,
				(b.comm - b.playercomm) AS comm,
				b.awinlost,
				b.mwinlost,
				b.swinlost,
				CASE b.custid WHEN b.creator THEN b.username ELSE '' END creator, 
				b.username,
				0 hthomescore,
				0 htawayscore,
				b.ip,
				b.betfrom,
				l.sporttype,
				b.matchid,
				0 IsNeutral,
				'' AS showtime,
				0 AS virtualrate,
				0 AS isShowOTExRate,
				0 finalodds,
				0 finalodds2,
				b.winlostdate,
				b.BetCheck,
				'' AS transdesc,
				0 AS OddsSpread,
				0 AS OriginalBetType,
				-1 AS BetdaqId,
				'' AS ExtraInfo
			FROM dbo.bettrans14 AS b WITH (NOLOCK)
				INNER JOIN dbo.outright14 AS odds WITH (NOLOCK) ON b.matchid = odds.orid
				INNER JOIN dbo.league AS l WITH (NOLOCK) ON odds.leagueid = l.leagueid
			WHERE b.bettype = 10
				AND b.winlostdate = @Date
				AND b.custid = @CustId
				AND l.SportType = 1
	) x
	WHERE ip = @ip

	-- Get more info for BetTrade tickets
	IF EXISTS (SELECT TOP 1 1 FROM @Data WHERE SportType = 1 AND BetType IN (901, 902))
	BEGIN
		UPDATE betList
		SET betList.Odds = originBetList.odds,
			betList.Stake = originBetList.stake,
			betList.LiveHomeScore = originBetList.livehomescore,
			betList.LiveAwayScore = originBetList.liveawayscore,
			betList.Comm = CASE
								WHEN betList.BetType = 902 THEN ISNULL(commBetList.AWinLost, 0)
								ELSE betList.comm
							END,
			betList.BetId = originBetList.Bettype
		FROM @Data AS betList
			INNER JOIN dbo.bettrans AS originBetList WITH (NOLOCK) ON betList.RefNo = originBetList.transid
			LEFT JOIN @Data AS commBetList ON betList.RefNo = commBetList.RefNo AND commBetList.Bettype = 903
		WHERE betList.SportType = 1 AND betList.BetType IN (901, 902)

		UPDATE betList
		SET betList.Odds = originBetList.Odds,
			betList.Stake = originBetList.Stake,
			betList.LiveHomeScore = originBetList.livehomescore,
			betList.LiveAwayScore = originBetList.liveawayscore,
			betList.Comm = CASE
								WHEN betList.Bettype = 902 THEN ISNULL(commBetList.AWinLost, 0)
								ELSE betList.comm
							END,
			betList.BetId = originBetList.Bettype
		FROM @Data AS betList
			INNER JOIN dbo.bettrans14 AS originBetList WITH (NOLOCK) ON betList.RefNO = originBetList.transid
			LEFT JOIN @Data AS commBetList ON betList.RefNO = commBetList.RefNO AND commBetList.Bettype = 903
		WHERE betList.SportType = 1 AND betList.BetType IN (901, 902)
	END

	-- Get more info for CashOut tickets
	IF EXISTS (SELECT TOP 1 1 FROM @Data WHERE BetType = 911)
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
		WHERE b.BetType = 911

		UPDATE b
		SET b.Odds = ob.odds,
			b.LiveIndicator = ob.liveindicator,
			b.LiveHomeScore = ob.livehomescore,
			b.LiveAwayScore = ob.liveawayscore,
			b.OriginalBetType = ob.bettype,
			b.BetdaqId = ob.transid
		FROM @Data AS b
			INNER JOIN dbo.bettrans14 AS ob WITH (NOLOCK) ON b.RefNo = ob.transid
		WHERE b.BetType = 911
	END

	IF EXISTS (SELECT TOP 1 1 FROM @Data WHERE BetType = 912)
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
			INNER JOIN dbo.bettrans AS cob WITH (NOLOCK) ON b.RefNo = cob.transid
			INNER JOIN dbo.bettrans AS ob WITH (NOLOCK) ON cob.RefNo = ob.transid
			LEFT JOIN @Data AS cb ON b.RefNo = cb.RefNo AND cb.BetType = 913
		WHERE b.BetType = 912

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
			INNER JOIN dbo.bettrans14 AS cob WITH (NOLOCK) ON b.RefNo = cob.transid
			INNER JOIN dbo.bettrans14 AS ob WITH (NOLOCK) ON cob.RefNo = ob.transid
			LEFT JOIN @Data AS cb ON b.RefNo = cb.RefNo AND cb.BetType = 913
		WHERE b.BetType = 912
	END

	DELETE @Data WHERE Bettype IN (903, 913)

	SELECT * FROM @Data
	ORDER BY 4,26

	-- Get ticket detail
	IF EXISTS ( SELECT TOP 1 1 FROM @Data WHERE BetType BETWEEN 1101 AND 1199 )
	BEGIN
		INSERT INTO @DetailData
		SELECT
			bg.refno,
			bg.odds,
			bg.stake,
			bg.status,
			bg.apositiontaking,
			bg.mpositiontaking,
			bg.spositiontaking,
			bg.bettype,
			bg.betteam
		FROM dbo.bettransg AS bg WITH (NOLOCK)
			INNER JOIN @Data AS b ON bg.refno = b.RefNo
		WHERE b.BetType BETWEEN 1101 AND 1199

		INSERT INTO @DetailData
		SELECT
			bg.refno,
			bg.odds,
			bg.stake,
			bg.status,
			bg.apositiontaking,
			bg.mpositiontaking,
			bg.spositiontaking,
			bg.bettype,
			bg.betteam
		FROM dbo.bettransg14 AS bg WITH (NOLOCK)
			INNER JOIN @Data AS b ON bg.refno = b.RefNo
		WHERE b.BetType BETWEEN 1101 AND 1199
	END

	SELECT DISTINCT * FROM @DetailData
END




GO
GRANT EXECUTE ON [dbo].[Acc_BetListByIP_Soccer] TO [bodbAdminNet]
GO
GRANT VIEW DEFINITION ON [dbo].[Acc_BetListByIP_Soccer] TO [vnteam]