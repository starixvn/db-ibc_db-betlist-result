ALTER PROCEDURE [dbo].[All_BetList_MatchResultAGSel]
	@TransId BIGINT 
AS
/*
Created: 20150916@Sophia
Task: Get Result from Betlist for AG Casino [#43637]
DB: DBAGE/bodb02; DBEXT/bodb02 

Original:   
  
Revisions: 	 
   			
Param's Explanation: 
	@TransID: TransId of Bettrans table

*/

BEGIN 
	SET NOCOUNT ON 

		DECLARE @TransDesc NVARCHAR(1000)

		SELECT	@TransDesc = TransDesc
		FROM	dbo.bettransLC WITH (NOLOCK)
		WHERE	TransId = @TransId
	
		IF @TransDesc IS NULL 
		BEGIN 
			SELECT	@TransDesc = TransDesc
			FROM	dbo.bettransLC14 WITH (NOLOCK)
			WHERE	TransId = @TransId
		END
		
		IF @TransDesc IS NULL 
		BEGIN 
			SELECT	@TransDesc = TransDesc
			FROM	DBARC.bodb_archive.dbo.bettransLC_BK WITH (NOLOCK)
			WHERE	TransId = @TransId
		END 

		SELECT @TransDesc as TransDesc 

END 
GO
