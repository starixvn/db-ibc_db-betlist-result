USE [bodb02]
GO
/****** Object:  StoredProcedure [dbo].[Age_Monitor_BetlistSel_Ag_OtherBettypes]    Script Date: 8/27/2015 3:59:56 PM ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO

ALTER PROCEDURE [dbo].[Age_Monitor_BetlistSel_Ag_OtherBettypes]
	@CustId			INT,
	@TransId		BIGINT	= 0,
	@LimitRowCount	INT		= 20
WITH RECOMPILE
AS

/*
	Created: Johnson
	Task: Monitor lastest bets list( all bettypes and others bettype not handicap and over/under)
	Date: 28/06/2011
	DB: DBAGE.bodb02
	Revision:
		- 20111122@Sophia: Add Checktime and SecAcceptFlag to show status waiting or running
		- 20120827@Jamie: Add actual_stake for System Parlay Bet list
		- 20130222@Elodie: Get custid value
		- 20130222@Elodie: Get oddsid value to use for Virtual HR
		- 20150302@Tom: Support 60 BetRadar (27218) Show betcheck coloum on Bettype 216,217 
		- 20150706@Bobby: Exclude Metric Gaming running ticket
		- 20150826@Kos: Add column OddsSpread to support Myanmar Odds and exclude Myanmar Odds bet types
		- 20160104@Kos: Support Sportsbook only and use SportBetTypeMatrix
		- 20160125@Kos: Support PH All In One 1.2 [Redmine: #50897]
		- 20160712@Kos: Change to use inline function for SportBettypeMatrix

	Parameter's Explanation:
		- @custid : agent ID
		- @transid: lastest transid 
		- @LimitRowCount: max record return.
*/ 

BEGIN
	SET NOCOUNT ON

	-- Get SportBettypeMatrix (support Sportsbook only)
	DECLARE @SportBettype TABLE (ProductID TINYINT, Bettype SMALLINT, EventType TINYINT)
	DECLARE @IsTest BIT = 0

	SELECT @IsTest = dbo.f_CheckSPVersion(@@PROCID)

	INSERT INTO @SportBettype
	SELECT ProductID, BetType, EventType
	FROM dbo.f_SportBettypeMatrix_Sel (0, 0, 0, 2, '', '', @IsTest)
	WHERE ProductID = 1

	SELECT TOP(@LimitRowCount)
		b.custid,
		0 AS sporttype,
		b.matchid,
		0 AS leagueid,
		b.Username,
		b.bettype,
		b.transid,
		b.refno,
		b.transdate,
		'' AS matchcode,
		0 AS homeid,
		0 AS awayid,
		b.oddsid AS Race,
		b.betid,
		b.livehomescore,
		b.liveawayscore,
		b.liveindicator,
		b.hdp1,
		b.hdp2,
		b.odds,
		b.stake,
		b.actual_stake,
		CASE 
			WHEN b.status = 'running' AND ISNULL(b.SecAcceptFlag, 0) = 1 AND ISNULL(b.checktime, CURRENT_TIMESTAMP) > CURRENT_TIMESTAMP THEN 'waiting'
			ELSE b.status
		END AS status,
		b.betteam,
		b.IP,
		CONVERT(BIT, 0) AS isNeutral,
		b.oddstype,
		ISNULL(b.Betcheck, '') AS Betcheck,
		ISNULL(b.transdesc, '') AS transdesc,
		0 AS OddsSpread
	FROM dbo.bettrans AS b WITH (NOLOCK)
		INNER JOIN @SportBettype AS s ON b.bettype = s.BetType
	WHERE b.recommend = @custid 
		AND b.statusID BETWEEN 0 AND 1
		AND b.bettype NOT IN (1, 3, 7, 8, 301, 302, 303, 304)		-- Exclude HDP & OU bettypes
		AND b.bettype < 19001
		AND b.transid > @transid
		AND b.bettype NOT BETWEEN 801 AND 806		-- Exclude Metric Gaming
	ORDER BY b.transid DESC
END



GO
GRANT EXECUTE ON [dbo].[Age_Monitor_BetlistSel_Ag_OtherBettypes] TO [bodbDownlineNet]
GO
GRANT EXECUTE ON [dbo].[Age_Monitor_BetlistSel_Ag_OtherBettypes] TO [bodbDownlineNetView]
GO
GRANT VIEW DEFINITION ON [dbo].[Age_Monitor_BetlistSel_Ag_OtherBettypes] TO [vnteam]