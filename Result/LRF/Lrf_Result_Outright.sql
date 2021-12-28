/*<info serverAlias="DBEXT-bodb02" executers="bodbLicenseeNet" viewers="" isFunction="0" isNested="0"></info>*/

ALTER PROCEDURE [dbo].[Lrf_Result_Outright]
	@FromDate	SMALLDATETIME,
	@ToDate		SMALLDATETIME,
	@IsShowAll	BIT 			= 1		-- 1: Show All; 0: is NOT show Test
AS

/*
	Created: 20101201@Jacob
	Task: Get Result Outright (exclude Horse Racing)
	DB: DBEXT.bodb02
	Original: Age_Result_Outright

	Revisions:
		- 20101201@Jacob: Copy source code from Age_Result_Outright
		- 20110308@Henry: exclude Greyhound & Harness racing sports (152,153)
		- 20110524@Henry: fix Show All/is not show test
		- 20110630@Jamie: Add REFUND Result cho Outright
		- 20211227@Kos: Exclude league and outright which IsDeleted = 1 [RedmineID: #163733]
*/

BEGIN
	SET NOCOUNT ON 

	SELECT @IsShowAll = CASE @IsShowAll WHEN 1 THEN NULL ELSE 0 END

	SELECT DISTINCT
		l.sporttype,
		o.leagueid,
		o.eventdate,
		o.teamid,
		o.status
	FROM (
			SELECT leagueid, eventdate, teamid, status
			FROM dbo.outright WITH (NOLOCK)
			WHERE oddsstatus = 'completed'
				AND status IN ('WON', 'REFUND')
				AND eventdate BETWEEN @FromDate AND @ToDate
				AND IsDeleted = 0
			UNION ALL
			SELECT leagueid, eventdate, teamid, status
			FROM dbo.outright14 WITH (NOLOCK)
			WHERE oddsstatus = 'completed'
				AND status IN ('WON', 'REFUND')
				AND eventdate BETWEEN @FromDate AND @ToDate
		) AS o
		INNER JOIN dbo.League AS l WITH (NOLOCK) ON o.leagueid = l.leagueid
	WHERE l.sporttype NOT IN (151, 152, 153)
		AND l.isTest = ISNULL(@IsShowAll, l.isTest)
		AND l.IsDeleted = 0
	ORDER BY o.leagueid,
		o.eventdate,
		o.teamid
END
GO
