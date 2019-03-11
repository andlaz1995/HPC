#include <cuda.h>
#include <stdio.h>
#include <string.h>
#include <sys/types.h>
#include <sys/time.h>
#define TX 16
#define TY 32

__global__
void doCopyKernel(float *d_colornew,float *d_color, int colsize, int rowsize)
{
    int Row = blockIdx.y*blockDim.y+threadIdx.y;
    int Col = blockIdx.x*blockDim.x+threadIdx.x;
    int x = Row*colsize+Col;

    if(Col<colsize && Row<rowsize)
        d_color[x] = d_colornew[x];

}
__global__ 
void performUpdatesKernel(float *d_colornew,float *d_color, int colsize, int rowsize)
{
    int Row = blockIdx.y*blockDim.y+threadIdx.y;
    int Col = blockIdx.x*blockDim.x+threadIdx.x;
    int x = Row*colsize+Col;
    int xm = x-colsize;
    int xp = x+colsize;

    if(Col<colsize && Row<rowsize){

		if (Row != 0 && Row != (rowsize-1) && Col != 0 && Col != (colsize-1)){
			d_colornew[x] = (d_color[xp]+d_color[xm]+d_color[x+1]+d_color[x-1])/4;				   
		}
		else if (Row == 0 && Col != 0 && Col != (colsize-1)){
			d_colornew[x] = (d_color[xp]+d_color[x+1]+d_color[x-1])/3;
		}
		else if (Row == (rowsize-1) && Col != 0 && Col != (colsize-1)){
			d_colornew[x] = (d_color[xm]+d_color[x+1]+d_color[x-1])/3;
		}
		else if (Col == 0 && Row != 0 && Row != (rowsize-1)){
			d_colornew[x] = (d_color[xm]+d_color[xp]+d_color[x+1])/3;
		}
		else if (Col == (colsize-1) && Row != 0 && Row != (rowsize-1)){
			d_colornew[x] = (d_color[xm]+d_color[xp]+d_color[x-1])/3;
		}
		else if (Row==0 &&Col==0){
			d_colornew[x] = (d_color[x+1]+d_color[xp])/2;
		}
		else if (Row==0 &&Col==(colsize-1)){
			d_colornew[x] = (d_color[x-1]+d_color[xp])/2;
		}
		else if (Row==(rowsize-1) &&Col==0){
			d_colornew[x] = (d_color[x+1]+d_color[xm])/2;
		}
		else if (Row==(rowsize-1) &&Col==(colsize-1)){
			d_colornew[x] = (d_color[x-1]+d_color[xm])/2;
		}
	}
}
void performUpdates(float *h_colornew, float *h_color, int colsize, int rowsize, int nblurs)
{
    float *d_color,*d_colornew;
    int k;
    struct timeval tim;

    int sizef = sizeof(int)*colsize*rowsize;


    gettimeofday(&tim, NULL);
	double memaloc1=tim.tv_sec+(tim.tv_usec/1000000.0);

    cudaMalloc((void **)&d_colornew,sizef);
    cudaMalloc((void **)&d_color,sizef);

    gettimeofday(&tim, NULL);
	double memaloc2=tim.tv_sec+(tim.tv_usec/1000000.0);
	printf(" Allocation of device memory took %.6lf seconds\n", memaloc2-memaloc1);

    gettimeofday(&tim, NULL);
	double host2dev1=tim.tv_sec+(tim.tv_usec/1000000.0);

    cudaMemcpy(d_color,h_color,sizef,cudaMemcpyHostToDevice);

    gettimeofday(&tim, NULL);
	double host2dev2=tim.tv_sec+(tim.tv_usec/1000000.0);
	printf(" Host to device transfer took %.6lf seconds\n", host2dev2-host2dev1);

    dim3 dimGrid(ceil(colsize/(float)TX),ceil(rowsize/(float)TY),1);
    dim3 dimBlock(TX,TY,1);

    gettimeofday(&tim, NULL);
	double bluring1=tim.tv_sec+(tim.tv_usec/1000000.0);
    for(k=0;k<nblurs;++k){
        performUpdatesKernel<<<dimGrid,dimBlock>>>(d_colornew,d_color,colsize,rowsize);
        doCopyKernel<<<dimGrid,dimBlock>>>(d_colornew,d_color,colsize,rowsize);
    }
    gettimeofday(&tim, NULL);
	double bluring2=tim.tv_sec+(tim.tv_usec/1000000.0);
	printf(" Bluring took %.6lf seconds\n", bluring2-bluring1);


    cudaThreadSynchronize();

    gettimeofday(&tim, NULL);
	double dev2host1=tim.tv_sec+(tim.tv_usec/1000000.0);

    cudaMemcpy(h_colornew,d_color,sizef,cudaMemcpyDeviceToHost);


    gettimeofday(&tim, NULL);
	double dev2host2=tim.tv_sec+(tim.tv_usec/1000000.0);
	printf(" Device to Host transfer took %.6lf seconds\n", dev2host2-dev2host1);

    cudaFree(d_colornew); cudaFree(d_color);
}





int main (int argc, char *argv[])
{
	static int const maxlen = 200, rowsize = 521, colsize = 428, linelen = 12;
	char str[maxlen], lines[5][maxlen];
	FILE *fp, *fout;
	int nlines = 0;
	unsigned int h1, h2, h3;
	char *sptr;
	int R[rowsize][colsize], G[rowsize][colsize], B[rowsize][colsize];
	int row = 0, col = 0, nblurs, lineno=0, k;
	struct timeval tim;

	gettimeofday(&tim, NULL);
	double inputfile1=tim.tv_sec+(tim.tv_usec/1000000.0);
	fp = fopen("David.ps", "r");
 
	while(! feof(fp))
	{
		fscanf(fp, "\n%[^\n]", str);
		if (nlines < 5) {strcpy((char *)lines[nlines++],(char *)str);}
		else{
			for (sptr=&str[0];*sptr != '\0';sptr+=6){
				sscanf(sptr,"%2x",&h1);
				sscanf(sptr+2,"%2x",&h2);
				sscanf(sptr+4,"%2x",&h3);
				
				if (col==colsize){
					col = 0;
					row++;
				}
				if (row < rowsize) {
					R[row][col] = h1;
					G[row][col] = h2;
					B[row][col] = h3;
				}
				col++;
			}
		}
	}
	fclose(fp);
	gettimeofday(&tim, NULL);
	double inputfile2=tim.tv_sec+(tim.tv_usec/1000000.0);
	printf(" Reading the input file took %.6lf seconds\n", inputfile2-inputfile1);


	nblurs = 10;

	float *h_Rnew, *h_R, *h_Gnew, *h_G, *h_Bnew, *h_B;

	int nsize1=sizeof(float)*colsize*rowsize;


	h_Rnew = (float *)malloc(nsize1);
    h_R = (float *)malloc(nsize1);

    h_Gnew = (float *)malloc(nsize1);
    h_G = (float *)malloc(nsize1);

    h_Bnew = (float *)malloc(nsize1);
    h_B = (float *)malloc(nsize1);

    for(row=0;row<rowsize;row++){
		for (col=0;col<colsize;col++){
			h_R[row*colsize+col] = R[row][col];
    		h_G[row*colsize+col] = G[row][col];
    		h_B[row*colsize+col] = B[row][col];
    	}
    }
    

	performUpdates(h_Rnew,h_R,colsize,rowsize,nblurs);
	performUpdates(h_Gnew,h_G,colsize,rowsize,nblurs);
	performUpdates(h_Bnew,h_B,colsize,rowsize,nblurs);

	

	for(row=0;row<rowsize;row++){
		for (col=0;col<colsize;col++){
			R[row][col]=h_Rnew[row*colsize+col];
    		G[row][col]=h_Gnew[row*colsize+col];
    		B[row][col]=h_Bnew[row*colsize+col];
    	}
    }



    gettimeofday(&tim, NULL);
	double outputfile1=tim.tv_sec+(tim.tv_usec/1000000.0);
	fout= fopen("DavidBlur.ps", "w");
	for (k=0;k<nlines;k++) fprintf(fout,"\n%s", lines[k]);
	fprintf(fout,"\n");
	for(row=0;row<rowsize;row++){
		for (col=0;col<colsize;col++){
			fprintf(fout,"%02x%02x%02x",R[row][col],G[row][col],B[row][col]);
			lineno++;
			if (lineno==linelen){
				fprintf(fout,"\n");
				lineno = 0;
			}
		}
	}
	fclose(fout);
	gettimeofday(&tim, NULL);
	double outputfile2=tim.tv_sec+(tim.tv_usec/1000000.0);
	printf(" Reading the output file took %.6lf seconds\n", outputfile2-outputfile1);
    return 0;	
}