/*<info serverAlias="DBBOF-bodb02" executers="bodbDownlineNet,bodbDownlineNetView" viewers="" isFunction="0" isNested="0"></info>*/
ALTER PROCEDURE [dbo].[Age_Monitor_OutrightSel]
(
	@isVSRacing BIT = 0
)
AS

/*	
	Created	: Johnson
	Task: Monitor lastest bets list- get outright running
	Date: 28/06/2011
	DB: DBBOF.BODB02
	Revision:
		- 20130228@Elodie: Add Virtual HR product
		- 20131212@Lukas: separate vsoutright and outright
		- 20231129@Razor: Support Project 777 - return LeagueGroupId [Redmine: #194591]

	Parameter's Explanation:		
		- @matchid: lastest outright's ID running got 
*/ 

 BEGIN
	SET NOCOUNT ON
	
	IF @isVSRacing = 1 
	BEGIN
		SELECT 
			r.sporttype AS sporttype,
			o.EventStatus AS status,
			o.Orid AS matchid,		
			r.leagueid,
			convert(nvarchar(50), o.RacerNum) matchcode,		
			o.RacerID AS homeid,
			0 AS awayid,
			o.Orid AS race,
			r.EventTime showtime,
			0 AS LeagueGroupId
		FROM dbo.VSOutright o WITH(NOLOCK)
			INNER JOIN dbo.VSRaceInfo r WITH(NOLOCK) ON o.EventID = r.EventID
		WHERE r.EventStatus <> 'completed' 
			AND eventdate >= CONVERT(varchar(10),DATEADD(dd,-1,CURRENT_TIMESTAMP),120)
	END
	ELSE
	BEGIN
		SELECT 
			l.sporttype AS sporttype,
			m.oddsstatus AS status,
			m.orid AS matchid,
			m.leagueid,
			m.matchcode,
			m.teamid AS homeid,
			0 AS awayid,
			ISNULL(m.groupmatch,'') AS race,
			'' showtime,
			l.LeagueGroupId
		FROM dbo.outright m WITH(NOLOCK)
			INNER JOIN dbo.league l WITH(NOLOCK) ON m.leagueid = l.leagueid
		WHERE oddsstatus <> 'completed' 
			AND eventdate >= CONVERT(varchar(10),DATEADD(dd,-1,CURRENT_TIMESTAMP),120)
	END 
 END