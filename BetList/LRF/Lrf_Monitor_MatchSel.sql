/*<info serverAlias="DBBOF-bodb02" executers="bodbLicenseeNet,wsv_lap" viewers="" isFunction="0" isNested="0"></info>*/

ALTER PROCEDURE [dbo].[Lrf_Monitor_MatchSel]
AS

/*
	Created: Henry@20111011
	Task: Monitor lastest bets list - get match running
	DB: DBBOF.bodb02
	Original: Age_Monitor_MatchSel
	Revision:
		- 20181008@Kos: Migrate to DB042 [RedmineID: #99464]
		- 20190509@Kos: Show match KO time for single ticket [Redmine: #112731]
					- Return additional column EventDate DATETIME

	Parameter's Explanation:
*/

BEGIN
	SET NOCOUNT ON

	SELECT
		sporttype,
		eventstatus AS Status,
		matchid,
		leagueid,
		matchcode,
		homeid,
		awayid,
		'' AS Race,
		GlobalShowTime AS EventDate
	FROM dbo.match WITH (NOLOCK)
	WHERE eventstatus <> 'completed'
END
GO


GRANT EXECUTE ON [dbo].[Lrf_Monitor_MatchSel] TO [bodbLicenseeNet]
GO
