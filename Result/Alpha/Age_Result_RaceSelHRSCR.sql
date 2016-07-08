ALTER PROCEDURE [dbo].[Age_Result_RaceSelHRSCR]
	@Eventdate	DATETIME,
	@LeagueID	INT,
	@RaceNo		VARCHAR(5)
AS
/*	Created:Jamie
	Date:2009-12-01
	Task: Scratch HR Information
	DB: DBAGE/BODB02 

	Revisions:
		- 20130121@Dan: change linked server DB06 to DBARC

*/
BEGIN
	SET NOCOUNT ON 
	IF EXISTS(SELECT 1 FROM Outright WITH (NOLOCK) WHERE leagueid = @leagueid AND eventdate=@eventdate)
	BEGIN
		SELECT	 matchcode
				,teamid 	
				,CONVERT(VARCHAR,SCRTime,108) SCRTime
				,risk Deduction
		FROM	Outright WITH (NOLOCK)
		WHERE	leagueid = @leagueid 
				AND groupmatch = @raceNo 
				AND eventdate = @eventdate 
				AND IsSCR = 1	
				AND FOddsStatus = 'completed'
		ORDER BY matchcode 
	END
	ELSE IF EXISTS(SELECT 1 FROM Outright14 WITH (NOLOCK) WHERE leagueid = @leagueid AND eventdate=@eventdate)
	BEGIN
		SELECT	 matchcode
				,teamid 	
				,CONVERT(VARCHAR,SCRTime,108) SCRTime
				,risk Deduction
		FROM	Outright14 WITH (NOLOCK)
		WHERE	leagueid = @leagueid 
				AND groupmatch = @raceNo 
				AND eventdate = @eventdate 
				AND IsSCR = 1	
				AND FOddsStatus = 'completed'
		ORDER BY matchcode 
	END
	ELSE
	BEGIN
		SELECT	 matchcode
				,teamid 	
				,CONVERT(VARCHAR,SCRTime,108) SCRTime
				,risk Deduction
		FROM	DBARC.bodb_archive.dbo.Outright_bk WITH (NOLOCK)
		WHERE	leagueid = @leagueid 
				AND groupmatch = @raceNo 
				AND eventdate = @eventdate 
				AND IsSCR = 1	
				AND FOddsStatus = 'completed'
		ORDER BY matchcode 
	END
END 
GO
GRANT EXECUTE ON [dbo].[Age_Result_RaceSelHRSCR] TO [bodbDownlineNet]
GO
GRANT EXECUTE ON [dbo].[Age_Result_RaceSelHRSCR] TO [bodbDownlineNetView]
GO
GRANT VIEW DEFINITION ON [dbo].[Age_Result_RaceSelHRSCR] TO [vnteam]