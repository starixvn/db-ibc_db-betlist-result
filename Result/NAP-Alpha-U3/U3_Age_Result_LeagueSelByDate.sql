/*<info serverAlias="DBAGE-bodb02" executers="bodbDownlineNet,bodbDownlineNetView" viewers="" isFunction="0" isNested="0"></info>*/

ALTER PROCEDURE [dbo].[U3_Age_Result_LeagueSelByDate]
	@EventDate	DATETIME,
	@Language	NVARCHAR(2)	= 'E',
	@SportType	SMALLINT	= 0,
	@IsShowAll	BIT			= 1 -- 1: Show All; 0: is NOT show Test
AS

/*
	Created: Kos@20170417
	Task:
	DB: DBAGE.bodb02
	Original: Age_Result_LeagueSelByDate

	Revisions: 
		- 20100524@Jamie: Only show Tote HR 
		- 20101207@Simon: Show All League or only show Live belong to @isShowAll.
		- 20110304@Lukas: get more sporttype 152, 153
		- 20110908@Sophia: Add Condition Where : (mr.ishtcal=1 OR mr.calculate=1)
		- 20111003@Sophia: Edit condition OR to show the row which have eventstatus IN ('running','closed')
		- 20130301@Elodie: Add Virtual HR product
		- 20130805@Lukas: Hide live casino game
		- 20131121@Kathy: Add Virtual Greyhounds (182), Virtual Motor Racing (184) [Redmine:#7234]
		- 20140404@Dom: Add Virtual Speedway (183), Virtual Cycling Racing (185) 
		- 20150414@Sophia: Support Betradar
		- 20150416@Sophia: Condition of showing Running match different between Sporting solution and BetRadar
		- 20150810@Sophia: Hardcode to exclude ResultDetail of bettype 216, 217 for a temporary time [#40991]
		- 20151014@Sophia: Show internal match [#45531]
		- 20160829@Kos: Include ResourceID '08' to support PH All In One phase 2b [#Redmine: 62882]
		- 20170417@Kos: Clone to support NAP/Alpha U3 [#Redmine: 75268]
		- 20170802@Kos: Change Sporttype data type to SMALLINT [Redmine: #73545]
		- 20170810@Kos: Support Lucky 3 [#Redmine: 75277]
		- 20181105@Kos: Support Happy 5 [#Redmine: 103850]
		- 20211117@Razor: Support In-house Replication [Redmine: #164321]
*/

BEGIN
	SET NOCOUNT ON

	SELECT @IsShowAll = CASE @IsShowAll WHEN 1 THEN NULL ELSE 0 END

	SELECT DISTINCT
		l.leaguename,
		l.leagueid,
		m.eventdate,
		m.sporttype
	FROM dbo.League AS l WITH (NOLOCK)
		INNER JOIN
			(
				SELECT matchid, leagueid, eventdate, eventstatus, sporttype
				FROM dbo.match WITH (NOLOCK)
				WHERE IsDeleted = 0
				UNION ALL
				SELECT matchid, leagueid, eventdate, eventstatus, sporttype
				FROM dbo.match14 WITH (NOLOCK)
			) m ON m.leagueid = l.leagueid
		LEFT OUTER JOIN dbo.match_remark AS mr WITH (NOLOCK) ON m.matchid = mr.matchid
	WHERE
		m.eventdate = @EventDate
		AND (m.eventstatus NOT IN ('closed', 'running')
			OR ( mr.IsPending = 1 AND m.eventstatus IN ('running', 'closed'))
			OR ( mr.IsHTCal = 1 AND m.eventstatus ='running'))
		AND m.sporttype IN (160, 161, 164)
		AND m.sporttype = CASE WHEN @SportType = 0 THEN m.sporttype ELSE @SportType END
		AND l.isTest = ISNULL(@IsShowAll, l.isTest)
		AND l.IsDeleted = 0
	ORDER BY m.sporttype,
		l.leaguename
END
GO