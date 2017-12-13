ALTER PROCEDURE [dbo].[Age_BetList_SelMatchResultSS]
	@matchid		INT,	
	@resourceid		VARCHAR(2)
AS
	/*
		Created: Johnson
		Date: 20101022
		Task: Get results for sporting solutions others bettype
		DB: DBAGE/bodb02
		
		Revisions:
			- 20130121@Dan: change linked server DB06 to DBARC
		
		Parameter's explanation:
	*/
SET NOCOUNT ON

	DECLARE @resultkey VARCHAR(50)
	
	SELECT @resultkey = 'set'+ @resourceid + 'summary'
	
	IF EXISTS (SELECT 1 FROM SS_GameState WITH(NOLOCK) WHERE matchid = @matchid)
	BEGIN
		SELECT ISNULL(resultvalue,'') as resultvalue
		FROM SS_GameState WITH(NOLOCK)
		WHERE matchid = @matchid AND resultkey = @resultkey
	END
	ELSE IF EXISTS(SELECT 1 FROM SS_GameState14 WITH(NOLOCK) WHERE matchid = @matchid)
	BEGIN
		SELECT ISNULL(resultvalue,'') as resultvalue
		FROM SS_GameState14 WITH(NOLOCK)
		WHERE matchid = @matchid AND resultkey = @resultkey
	END
	ELSE IF EXISTS(SELECT 1 FROM DBARC.bodb_Archive.dbo.SS_GameState_bk WITH(NOLOCK) WHERE matchid = @matchid)
	BEGIN
		SELECT ISNULL(resultvalue,'') as resultvalue
		FROM DBARC.bodb_Archive.dbo.SS_GameState_bk WITH(NOLOCK)
		WHERE matchid = @matchid AND resultkey = @resultkey
	END
GO
GRANT EXECUTE ON [dbo].[Age_BetList_SelMatchResultSS] TO [bodbDownlineNet] 
GO
GRANT EXECUTE ON [dbo].[Age_BetList_SelMatchResultSS] TO [bodbDownlineNetView]
GO
