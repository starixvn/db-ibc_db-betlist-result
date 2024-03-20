/*<info serverAlias="DBBOF-bodb02" executers="bodbLicenseeNet,wsv_lap" viewers="" isFunction="0" isNested="0"></info>*/

ALTER PROCEDURE [dbo].[Lrf_Monitor_MatchSelById]
	@MatchId INT
AS

/*
	Created: 20220606@Kos
	Task: LAP - Last Bets Monitoring - Get running match info by ID
	DB: DBBOF.bodb02

	Revision:
		- 20220606@Kos: Created [RedmineID: #173737]
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
	WHERE matchid = @MatchId
END
GO
