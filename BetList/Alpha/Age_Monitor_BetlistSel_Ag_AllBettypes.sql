USE [bodb02]
GO

ALTER PROCEDURE [dbo].[Age_Monitor_BetlistSel_Ag_AllBettypes]
	@custid			INT,
	@transid		BIGINT	= 0,
	@LimitRowCount	INT		= 20 
AS

/*
	Created: Johnson
	Task: Monitor lastest bets list( all bettypes and all sports)
	Date: 28/06/2011
	DB: DBAGE.BODB02
	Revision:
		- 20111122@Sophia: Add Checktime and SecAcceptFlag to show status waiting or running
		- 20120827@Jamie: Add actual_stake for System Parlay Bet list 
		- 20130222@Elodie: Get custid value
		- 20130222@Elodie: Get oddsid value to use for Virtual HR
		- 20150318@Cody: Apply sporttype bettype matrix
		- 20150706@Bobby: Exclude Metric Gaming running ticket
		- 20150826@Kos: Add column OddsSpread to support Myanmar Odds
		- 20150904@Kos: Correct data type of temp table
		- 20160104@Kos: Support Sportsbook only
		- 20160125@Kos: Support PH All In One 1.2 [Redmine: #50897]
		- 20160308@Francis: Change to use inline function instead of table variable to enhance performance
		- 20160623@Percy: Remove WITH recompile [RedmineID: #58288]
	Parameter's Explanation:
		- @custid : agent's ID
		- @transid: lastest transid 
		- @LimitRowCount: max record return.
*/ 

BEGIN
	SET NOCOUNT ON

	DECLARE @isTest BIT

	SELECT @IsTest = dbo.f_CheckSPVersion(@@PROCID)

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
		ISNULL(b.oddsspread, 0) AS OddsSpread
	FROM dbo.bettrans AS b WITH (NOLOCK)
		INNER JOIN dbo.f_SportBettypeMatrix_Sel_Mode4(1, 0, 0, 2, '', '', @IsTest) s ON b.bettype = s.Bettype
	WHERE b.recommend = @custid 
		AND b.transid > @transid
		AND b.statusID BETWEEN 0 AND 1
		AND b.bettype NOT BETWEEN 801 AND 806
	ORDER BY b.transid DESC

END


GO
GRANT EXECUTE ON [dbo].[Age_Monitor_BetlistSel_Ag_AllBettypes] TO [bodbDownlineNet] AS [dbo]
GO
GRANT EXECUTE ON [dbo].[Age_Monitor_BetlistSel_Ag_AllBettypes] TO [bodbDownlineNetView] AS [dbo]
GO
GRANT VIEW DEFINITION ON [dbo].[Age_Monitor_BetlistSel_Ag_AllBettypes] TO [vnteam] AS [dbo]