ALTER PROCEDURE dbo.Acc_BetList_HRResults
 (	
	 @leagueid	int
	,@raceNo	varchar(5)
	,@eventdate datetime
  )
AS 
/*	Created: []
	Date:[]
	DB: DBAGE/BODB02
	
	Revisions:
		- 20091104@Jamie: No need to check the condition in showing results  
		- 20091125@Simon: Add SCR Info (SCRTime, Deduction).
		- 20091130@Jamie: Get Results from bodb_archive
		- 20100805@Kiwi: Grant [bodbExtAccNet]
		- 20130121@Dan: change linked server DB06 to DBARC
*/
BEGIN 
	SET NOCOUNT ON
	IF EXISTS( SELECT 1 FROM outright WITH (NOLOCK) WHERE leagueid = @leagueid and eventdate = @eventdate)
	BEGIN
		SELECT	 matchcode
				,teamid 	 
				,isnull(placing,0) placing
		FROM	Outright WITH (NOLOCK) 
		WHERE	leagueid = @leagueid 
				AND groupmatch = @raceNo 
				AND eventdate = @eventdate 
				AND isnull(placing ,0) <>0
		ORDER BY placing 

		exec dbo.Acc_Set_HR_ResultSCRSel @leagueid=@leagueid,@raceNo=@raceNo,@eventdate=@eventdate
	END 	
	ELSE IF EXISTS (SELECT 1 FROM outright14 WITH (NOLOCK) WHERE leagueid = @leagueid and eventdate = @eventdate)
	BEGIN
		SELECT	 matchcode
				,teamid 	 
				,isnull(placing,0) placing
		FROM	Outright14 WITH (NOLOCK) 
		WHERE	leagueid = @leagueid 
				AND groupmatch = @raceNo 
				AND eventdate = @eventdate 
				AND isnull(placing ,0) <>0
		ORDER BY placing 

		exec dbo.Acc_Set_HR_ResultSCRSel @leagueid=@leagueid,@raceNo=@raceNo,@eventdate=@eventdate
	END	
	ELSE 
	BEGIN
		SELECT	 matchcode
				,teamid 	 
				,isnull(placing,0) placing
		FROM	DBARC.bodb_archive.dbo.Outright_bk WITH (NOLOCK) 
		WHERE	leagueid = @leagueid 
				AND groupmatch = @raceNo 
				AND eventdate = @eventdate 
				AND isnull(placing ,0) <>0
		ORDER BY placing 

		exec dbo.Acc_Set_HR_ResultSCRSel @leagueid=@leagueid,@raceNo=@raceNo,@eventdate=@eventdate
	END 
END

GO
GRANT EXECUTE ON [dbo].[Acc_BetList_HRResults] TO [bodbAdminNet]
GO
GRANT EXECUTE ON [dbo].[Acc_BetList_HRResults] TO [bodbExtAccNet]
GO
GRANT EXECUTE ON [dbo].[Acc_BetList_HRResults] TO [vnteam]
GO
