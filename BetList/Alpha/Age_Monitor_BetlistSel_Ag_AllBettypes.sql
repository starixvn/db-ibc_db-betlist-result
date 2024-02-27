/*<info serverAlias="DBBOF-bodb02" executers="bodbDownlineNet,bodbDownlineNetView" viewers="" isFunction="0" isNested="0"></info>*/

ALTER PROCEDURE [dbo].[Age_Monitor_BetlistSel_Ag_AllBettypes]
	@CustId			INT,
	@TransId		BIGINT	= 0,
	@LimitRowCount	INT		= 20
AS

/*
	Created: Johnson@20110628
	Task: Last Bets
	DB: DBBOF.bodb02
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
		- 20180802@Patrick: indexes revolution [RedmineID: #98757]
		- 20181218@Kos: Support E-Sports phase 2b [#Redmine: 106456]
		- 20190107@Kos: Support Parlay Changes [#Redmine: 105585]
		- 20190722@Kos: Support new status Pending [#Redmine: 113142]
		- 20191028@Kos: Show Running status for Marked tickets [Redmine: 122391]
		- 20231004@Kos: Support Parlay Boost [Redmine: #194992]
		- 20231019@Razor: Return Device Type info [Redmine: #192667]
		- 20240226@Kos: Get original odds for Mix Parlay from ExtraInfo [Redmine: #196425]

	Parameter's Explanation:
		- @CustId: agent's ID
		- @TransId: latest transid
		- @LimitRowCount: max record return
*/

BEGIN
	SET NOCOUNT ON

	DECLARE @IsTest BIT

	SELECT @IsTest = dbo.f_CheckSPVersion(@@PROCID)

	; WITH __bettypeList AS (
		SELECT BetType
		FROM dbo.SportBettypeMatrix WITH (NOLOCK)
		WHERE ProductID = 1 AND IsTest IN (0, @IsTest)
		GROUP BY BetType
	)

	SELECT TOP(@LimitRowCount)
		b.custid,
		b.matchid,
		b.Username,
		b.bettype,
		b.transid,
		b.refno,
		b.transdate,
		b.oddsid AS Race,
		b.betid,
		b.livehomescore,
		b.liveawayscore,
		b.liveindicator,
		b.hdp1,
		b.hdp2,
		b.odds,
		b.modds,
		b.stake,
		b.actual_stake,
		CASE
			WHEN b.bettype NOT IN (9, 29) AND b.status = 'running' AND ISNULL(b.SecAcceptFlag, 0) = 1 AND ISNULL(b.checktime, CURRENT_TIMESTAMP) > CURRENT_TIMESTAMP THEN 'waiting'
			WHEN b.bettype IN (9, 29) AND b.status = 'running' THEN
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
		END AS status,
		b.betteam,
		b.ip,
		b.oddstype,
		ISNULL(b.betcheck, '') AS Betcheck,
		ISNULL(b.transdesc, '') AS transdesc,
		ISNULL(b.oddsspread, 0) AS OddsSpread,
		ISNULL(b.ExtraInfo, '') AS ExtraInfo,
		b.DeviceType
	FROM dbo.bettrans AS b WITH (NOLOCK)
	WHERE b.recommend = @CustId 
		AND b.transid > @TransId
		AND b.statusID IN (0, 1)
		AND b.bettype NOT BETWEEN 801 AND 806
		AND EXISTS (SELECT TOP 1 1 FROM __bettypeList AS s WHERE b.bettype = s.Bettype)
	ORDER BY b.transid DESC
END
GO
