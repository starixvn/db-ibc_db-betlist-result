ALTER PROCEDURE [dbo].[All_BetList_MatchResultGDSel]
	@TransId BIGINT 
AS
/*
Created: 20150505@Sophia
Task: Get Result from Betlist for Gold Delux 
DB: DBAGE/bodb02; DBEXT/bodb02 

Original:   
  
Revisions: 	 
   			
Param's Explanation: 
	@TransID: TransId of Bettrans table

*/

BEGIN 
	SET NOCOUNT ON 

	IF EXISTS (SELECT TOP 1 1 FROM dbo.Bettrans WITH (NOLOCK) WHERE TransId = @TransId)
	BEGIN 
		SELECT	DISTINCT TransDesc
		FROM	dbo.BettransG WITH (NOLOCK)
		WHERE	RefNo = @TransId
		END 
	ELSE 
	IF EXISTS (SELECT TOP 1 1 FROM dbo.Bettrans14 WITH (NOLOCK) WHERE TransId = @TransId)
	BEGIN
		SELECT	DISTINCT TransDesc
		FROM	dbo.BettransG14 WITH (NOLOCK)
		WHERE	RefNo = @TransId
	END
	ELSE
	IF EXISTS (SELECT TOP 1 1 FROM DBARC.bodb_archive.dbo.Bettrans_BK WITH (NOLOCK) WHERE TransId = @TransId)
	BEGIN 
		SELECT	DISTINCT TransDesc
		FROM	DBARC.bodb_archive.dbo.BettransG WITH (NOLOCK)
		WHERE	RefNo = @TransId
	END
	
END 


GO 
GRANT EXECUTE ON [dbo].[All_BetList_MatchResultGDSel] TO [bodbDownlineNet]
GO 
GRANT EXECUTE ON [dbo].[All_BetList_MatchResultGDSel] TO [bodbExtAccNet]
GO 
GRANT EXECUTE ON [dbo].[All_BetList_MatchResultGDSel] TO [bodbDownlineNetView]
GO 
GRANT EXECUTE ON [dbo].[All_BetList_MatchResultGDSel] TO [bodbAdminNet]
GO 
GRANT EXECUTE ON [dbo].[All_BetList_MatchResultGDSel] TO [bodbLicenseeNet]
GO


 